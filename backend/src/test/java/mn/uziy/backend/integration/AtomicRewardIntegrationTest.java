package mn.uziy.backend.integration;

import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryRepository;
import mn.uziy.backend.security.JwtPrincipal;
import mn.uziy.backend.viewer.RewardResult;
import mn.uziy.backend.viewer.SubmitSurveyReq;
import mn.uziy.backend.viewer.ViewerController;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * The only spec §4C guarantee that mocks can't prove: that the SERIALIZABLE
 * reward transaction actually rolls back atomically against a real Postgres.
 *
 * <p>Boots Spring against a fresh Postgres in Docker (Testcontainers), runs
 * Flyway migrations, then exercises the reward transaction directly through
 * the controller.
 */
@SpringBootTest
@Testcontainers
class AtomicRewardIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("zoos_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired ViewerController viewerController;
    @Autowired UserRepository users;
    @Autowired CampaignRepository campaigns;
    @Autowired SurveyQuestionRepository questions;
    @Autowired ViewHistoryRepository history;
    @Autowired PasswordEncoder encoder;

    /**
     * Populate the security context so @PreAuthorize("hasRole('VIEWER')")
     * lets the controller method run. We're calling through Spring's AOP
     * proxy, so the annotation is still enforced even though there's no HTTP
     * request.
     */
    private void authAs(long userId) {
        authAs(userId, Role.VIEWER);
    }

    private void authAs(long userId, Role role) {
        JwtPrincipal principal = new JwtPrincipal(userId, role);
        var auth = new UsernamePasswordAuthenticationToken(
                principal, null, List.of(new SimpleGrantedAuthority("ROLE_" + role.name())));
        SecurityContextHolder.getContext().setAuthentication(auth);
    }

    @AfterEach
    void clearAuth() {
        SecurityContextHolder.clearContext();
    }

    private UserEntity freshViewer(String phone) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(phone);
        u.setPasswordHash(encoder.encode("password"));
        u.setRole(Role.VIEWER);
        u.setGender(Gender.MALE);
        u.setBirthDate(LocalDate.now().minusYears(26));
        u.setCity("Улаанбаатар");
        u.setBalance(0.0);
        return users.save(u);
    }

    private UserEntity freshCompany(String phone) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(phone);
        u.setPasswordHash("x");
        u.setRole(Role.COMPANY);
        u.setCompanyName("Co");
        return users.save(u);
    }

    private CampaignEntity freshActiveCampaign(long companyId, double budget) {
        CampaignEntity c = new CampaignEntity();
        c.setCompanyId(companyId);
        c.setTitle("Test");
        c.setDurationSeconds(30);
        c.setTargetGender(TargetGender.ALL);
        c.setMinAge(18);
        c.setMaxAge(45);
        c.setTargetCity("Улаанбаатар");
        c.setTotalBudget(budget);
        c.setRemainingBudget(budget);
        c.setCostPerView(1000.0);
        c.setRewardPerUser(700.0);
        c.setStatus(CampaignStatus.ACTIVE);
        CampaignEntity saved = campaigns.save(c);

        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setCampaignId(saved.getId());
        q.setPosition(1);
        q.setPrompt("P");
        q.setQType("SINGLE_CHOICE");
        q.setOptionsJson("[\"A\",\"B\"]");
        q.setRequired(true);
        questions.save(q);
        return saved;
    }

    private static SubmitSurveyReq answerA(long questionId) {
        return new SubmitSurveyReq(List.of(new SubmitSurveyReq.Answer(questionId, "\"A\"")));
    }

    @Test
    void submit_credits_reward_decrements_budget_records_history_all_persisted() {
        UserEntity company = freshCompany("80000001");
        CampaignEntity campaign = freshActiveCampaign(company.getId(), 5_000_000.0);
        UserEntity viewer = freshViewer("70000001");
        SurveyQuestionEntity q = questions.findAllByCampaignIdOrderByPosition(campaign.getId()).get(0);

        authAs(viewer.getId());
        RewardResult result = viewerController.submit(
                campaign.getId(), answerA(q.getId()), new JwtPrincipal(viewer.getId(), Role.VIEWER));

        assertThat(result.rewardPaid()).isEqualTo(700.0);
        assertThat(result.newBalance()).isEqualTo(700.0);

        UserEntity reloadedUser = users.findById(viewer.getId()).orElseThrow();
        CampaignEntity reloadedCampaign = campaigns.findById(campaign.getId()).orElseThrow();
        assertThat(reloadedUser.getBalance()).isEqualTo(700.0);
        assertThat(reloadedCampaign.getRemainingBudget()).isEqualTo(4_999_000.0);
        assertThat(history.existsByUserIdAndCampaignId(viewer.getId(), campaign.getId())).isTrue();
    }

    @Test
    void submit_twice_for_the_same_campaign_is_rejected_no_double_reward() {
        UserEntity company = freshCompany("80000002");
        CampaignEntity campaign = freshActiveCampaign(company.getId(), 5_000_000.0);
        UserEntity viewer = freshViewer("70000002");
        SurveyQuestionEntity q = questions.findAllByCampaignIdOrderByPosition(campaign.getId()).get(0);

        authAs(viewer.getId());
        viewerController.submit(
                campaign.getId(), answerA(q.getId()), new JwtPrincipal(viewer.getId(), Role.VIEWER));

        assertFailsWithHttp(() -> viewerController.submit(
                campaign.getId(), answerA(q.getId()), new JwtPrincipal(viewer.getId(), Role.VIEWER)));

        UserEntity reloadedUser = users.findById(viewer.getId()).orElseThrow();
        assertThat(reloadedUser.getBalance())
                .as("reward should not have been paid twice").isEqualTo(700.0);
    }

    @Test
    void submit_fails_when_campaign_budget_is_exhausted_no_side_effects() {
        UserEntity company = freshCompany("80000003");
        // Budget exactly one view; drain it via a first viewer, then a second
        // viewer must fail.
        CampaignEntity campaign = freshActiveCampaign(company.getId(), 1000.0);
        SurveyQuestionEntity q = questions.findAllByCampaignIdOrderByPosition(campaign.getId()).get(0);

        UserEntity first = freshViewer("70000003");
        authAs(first.getId());
        viewerController.submit(
                campaign.getId(), answerA(q.getId()), new JwtPrincipal(first.getId(), Role.VIEWER));

        UserEntity second = freshViewer("70000004");
        authAs(second.getId());
        assertFailsWithHttp(() -> viewerController.submit(
                campaign.getId(), answerA(q.getId()), new JwtPrincipal(second.getId(), Role.VIEWER)));

        UserEntity reloadedSecond = users.findById(second.getId()).orElseThrow();
        CampaignEntity reloadedCampaign = campaigns.findById(campaign.getId()).orElseThrow();
        assertThat(reloadedSecond.getBalance())
                .as("second viewer must not have been credited").isEqualTo(0.0);
        assertThat(reloadedCampaign.getRemainingBudget()).isEqualTo(0.0);
    }
}
