package mn.uziy.backend.integration;

import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import mn.uziy.backend.admin.AdminController;
import mn.uziy.backend.common.DomainException;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.company.CompanyController;
import mn.uziy.backend.company.CompanyMessages;
import mn.uziy.backend.company.CreateCampaignReq;
import mn.uziy.backend.company.PayCampaignResponse;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtPrincipal;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.settings.PlatformSettingsController;
import mn.uziy.backend.settings.PlatformSettingsServiceImpl;
import mn.uziy.backend.settings.UpdatePlatformSettingsReq;
import mn.uziy.backend.viewer.RewardResult;
import mn.uziy.backend.viewer.SubmitSurveyReq;
import mn.uziy.backend.viewer.ViewerController;
import mn.uziy.backend.web.ApiExceptionHandler;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import tools.jackson.databind.ObjectMapper;

/**
 * Commission pricing + per-campaign payment against a real Postgres that
 * ran Flyway V1..V5 on top of the V2 dev seed (so V5's backfill ran over
 * existing campaigns). Controllers are called through their Spring proxies,
 * so @PreAuthorize and @Transactional are live.
 *
 * <p>Seed ids used: admin 1, MobiCom (company) 2, Golomt Bank (company) 3,
 * viewer 100 (male, 24, Улаанбаатар).
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class CampaignPaymentFlowIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_payment_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
        registry.add("uziy.payments.simulated", () -> "true");
    }

    static final long ADMIN = 1L;
    static final long MOBICOM = 2L;
    static final long GOLOMT = 3L;
    static final long VIEWER = 100L;

    @Autowired CompanyController company;
    @Autowired AdminController admin;
    @Autowired ViewerController viewer;
    @Autowired PlatformSettingsController settings;
    @Autowired CampaignRepository campaigns;
    @Autowired SurveyQuestionRepository questions;
    @Autowired JdbcTemplate jdbc;
    @Autowired ObjectMapper json;
    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired UserRepository users;

    private String bearer(long userId) {
        return "Bearer " + jwt.issue(users.findById(userId).orElseThrow());
    }

    private void authAs(long userId, Role role) {
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                new JwtPrincipal(userId, role), null,
                List.of(new SimpleGrantedAuthority("ROLE_" + role.name()))));
    }

    private static JwtPrincipal principal(long userId, Role role) {
        return new JwtPrincipal(userId, role);
    }

    @AfterEach
    void clearAuth() {
        SecurityContextHolder.clearContext();
    }

    private static CreateCampaignReq createReq(String title, double totalBudget,
                                               Integer targetViewers, Double rewardPerUser) {
        return new CreateCampaignReq(
                title, "https://cdn.example/v.m3u8", true,
                30, TargetGender.ALL, 18, 45, "Улаанбаатар",
                totalBudget, targetViewers, rewardPerUser,
                List.of(new CreateCampaignReq.NewQuestion(
                        "Сонирхолтой санагдсан уу?", "SINGLE_CHOICE", List.of("Тийм", "Үгүй"), true)));
    }

    private static CreateCampaignReq createReq() {
        return createReq("Интеграцийн тест", 1_000_000.0, 1_000, null);
    }

    private CampaignDto createAsMobiCom(CreateCampaignReq req) {
        authAs(MOBICOM, Role.COMPANY);
        return company.create(req, principal(MOBICOM, Role.COMPANY));
    }

    private int paidRows(long campaignId) {
        Integer n = jdbc.queryForObject(
                "SELECT COUNT(*) FROM campaign_payments WHERE campaign_id = ? AND status = 'PAID'",
                Integer.class, campaignId);
        return n == null ? 0 : n;
    }

    private Integer viewersOf(long id) {
        return jdbc.queryForObject("SELECT target_viewers FROM campaigns WHERE id = ?", Integer.class, id);
    }

    // --- migration over seeded data ---------------------------------------

    @Test
    void V5_backfilled_the_seeded_campaigns_and_replaced_the_survey_pricing_columns() {
        assertThat(viewersOf(1)).isEqualTo(5000); // 5,000,000 / 1000
        assertThat(viewersOf(2)).isEqualTo(3750); // 3,000,000 / 800
        assertThat(viewersOf(3)).isEqualTo(3333); // 4,000,000 / 1200, floored

        CampaignEntity legacy = campaigns.findById(3L).orElseThrow();
        assertThat(legacy.getStatus()).as("seeded statuses are untouched").isEqualTo(CampaignStatus.PENDING);
        assertThat(legacy.getCommissionPercent()).isNull();
        assertThat(legacy.getPaidAt()).isNull();

        var s = settings.get();
        assertThat(s.commissionPercent()).isEqualTo(30);
        assertThat(s.minRewardPerViewer()).isEqualTo(100);
        Integer surveyCols = jdbc.queryForObject("""
                SELECT COUNT(*) FROM information_schema.columns
                WHERE table_name = 'platform_settings' AND column_name LIKE 'survey_only%'
                """, Integer.class);
        assertThat(surveyCols).isEqualTo(0);
    }

    // --- the whole happy path ---------------------------------------------

    @Test
    void create_pay_admin_approves_viewer_is_rewarded() {
        // 1. Company creates from JSON that still carries a stale costPerView:
        //    it must be ignored, the server prices with the platform commission.
        CreateCampaignReq body = json.readValue("""
                {"title":"5G багц","hasVideo":true,"videoUrl":"https://cdn.example/5g.m3u8",
                 "durationSeconds":30,"targetGender":"ALL","minAge":18,"maxAge":45,
                 "targetCity":"Улаанбаатар","totalBudget":1000000,"targetViewers":1000,
                 "costPerView":1,
                 "questions":[{"prompt":"Та 5G ашигладаг уу?","type":"SINGLE_CHOICE","options":["Тийм","Үгүй"]}]}
                """, CreateCampaignReq.class);
        authAs(MOBICOM, Role.COMPANY);
        CampaignDto created = company.create(body, principal(MOBICOM, Role.COMPANY));
        long id = created.id();
        assertThat(created.status()).isEqualTo(CampaignStatus.AWAITING_PAYMENT);
        assertThat(created.costPerView()).isEqualTo(1000.0);
        assertThat(created.rewardPerUser()).isEqualTo(700.0);
        assertThat(created.targetViewers()).isEqualTo(1000);
        assertThat(created.commissionPercent()).isEqualTo(30);
        assertThat(created.totalBudget()).isEqualTo(1_000_000.0);
        assertThat(created.paidAt()).isNull();

        // 2. Unpaid -> invisible to viewers, not moderatable, company can't self-activate.
        authAs(VIEWER, Role.VIEWER);
        assertThat(viewer.feed(principal(VIEWER, Role.VIEWER)).stream().noneMatch(i -> i.id() == id)).isTrue();

        authAs(ADMIN, Role.ADMIN);
        var unpaid = assertFailsWithHttp(() -> admin.moderate(id, CampaignStatus.ACTIVE));
        assertThat(unpaid.statusCode()).isEqualTo(HttpStatus.CONFLICT);

        authAs(MOBICOM, Role.COMPANY);
        var selfActivate = assertFailsWithHttp(
                () -> company.setStatus(id, CampaignStatus.ACTIVE, principal(MOBICOM, Role.COMPANY)));
        assertThat(selfActivate.statusCode()).isEqualTo(HttpStatus.CONFLICT);

        // 3. Another company can neither pay for it nor see its payment.
        authAs(GOLOMT, Role.COMPANY);
        var foreign = assertFailsWithHttp(() -> company.pay(id, principal(GOLOMT, Role.COMPANY)));
        assertThat(foreign.statusCode()).isEqualTo(HttpStatus.FORBIDDEN);

        // 4. Owner pays.
        authAs(MOBICOM, Role.COMPANY);
        PayCampaignResponse paid = company.pay(id, principal(MOBICOM, Role.COMPANY));
        assertThat(paid.campaign().status()).isEqualTo(CampaignStatus.PENDING);
        assertThat(paid.campaign().paidAt()).isNotNull();
        assertThat(paid.payment().amount()).isEqualTo(1_000_000.0);
        assertThat(paid.payment().provider()).isEqualTo(PaymentProvider.SIMULATED);
        assertThat(paid.payment().status()).isEqualTo(PaymentStatus.PAID);
        assertThat(paid.payment().reference()).matches("UZ-\\d{8}-" + id);
        assertThat(paid.payment().campaignTitle()).isEqualTo("5G багц");

        CampaignEntity stored = campaigns.findById(id).orElseThrow();
        assertThat(stored.getStatus()).isEqualTo(CampaignStatus.PENDING);
        assertThat(stored.getPaidAt()).isNotNull();
        assertThat(stored.getRemainingBudget())
                .as("paying must not touch the budget").isEqualTo(1_000_000.0);
        assertThat(paidRows(id)).isEqualTo(1);

        // Paying twice is a 409, still one PAID row.
        var twice = assertFailsWithHttp(() -> company.pay(id, principal(MOBICOM, Role.COMPANY)));
        assertThat(twice.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(paidRows(id)).isEqualTo(1);

        // Payment history is scoped to the owner.
        assertThat(company.payments(principal(MOBICOM, Role.COMPANY)).stream()
                .anyMatch(p -> p.campaignId() == id)).isTrue();
        authAs(GOLOMT, Role.COMPANY);
        assertThat(company.payments(principal(GOLOMT, Role.COMPANY)).stream()
                .noneMatch(p -> p.campaignId() == id)).isTrue();

        // 5. PENDING is still not self-activatable — moderation can't be skipped.
        authAs(MOBICOM, Role.COMPANY);
        assertFailsWithHttp(() -> company.setStatus(id, CampaignStatus.ACTIVE, principal(MOBICOM, Role.COMPANY)));

        // 6. Admin approves; the detail carries the snapshot + paidAt.
        authAs(ADMIN, Role.ADMIN);
        CampaignDto approved = admin.moderate(id, CampaignStatus.ACTIVE);
        assertThat(approved.status()).isEqualTo(CampaignStatus.ACTIVE);
        var detail = admin.getCampaign(id);
        assertThat(detail.campaign().commissionPercent()).isEqualTo(30);
        assertThat(detail.campaign().paidAt()).isNotNull();

        // 7. Viewer sees it and is rewarded R; budget drops by C.
        authAs(VIEWER, Role.VIEWER);
        assertThat(viewer.feed(principal(VIEWER, Role.VIEWER)).stream().anyMatch(i -> i.id() == id)).isTrue();
        List<SurveyQuestionEntity> qs = questions.findAllByCampaignIdOrderByPosition(id);
        assertThat(qs).hasSize(1);
        RewardResult reward = viewer.submit(
                id,
                new SubmitSurveyReq(List.of(new SubmitSurveyReq.Answer(qs.get(0).getId(), "\"Тийм\""))),
                principal(VIEWER, Role.VIEWER));
        assertThat(reward.rewardPaid()).isEqualTo(700.0);
        assertThat(campaigns.findById(id).orElseThrow().getRemainingBudget()).isEqualTo(999_000.0);

        // 8. Company can now pause / resume / complete.
        authAs(MOBICOM, Role.COMPANY);
        JwtPrincipal me = principal(MOBICOM, Role.COMPANY);
        assertThat(company.setStatus(id, CampaignStatus.PAUSED, me).status()).isEqualTo(CampaignStatus.PAUSED);
        assertThat(company.setStatus(id, CampaignStatus.ACTIVE, me).status()).isEqualTo(CampaignStatus.ACTIVE);
        assertThat(company.setStatus(id, CampaignStatus.COMPLETED, me).status())
                .isEqualTo(CampaignStatus.COMPLETED);
        CampaignEntity after = campaigns.findById(id).orElseThrow();
        assertThat(after.getStatus()).isEqualTo(CampaignStatus.COMPLETED);
        assertThat(after.getRemainingBudget())
                .as("status changes must not rewrite the budget").isEqualTo(999_000.0);
    }

    @Test
    void REWARD_mode_is_priced_and_charged_server_side() {
        CampaignDto created = createAsMobiCom(createReq("Интеграцийн тест", 1_000_000.0, null, 500.0));
        assertThat(created.costPerView()).isEqualTo(715.0);
        assertThat(created.targetViewers()).isEqualTo(1398);
        assertThat(created.totalBudget()).isEqualTo(999_570.0);

        PayCampaignResponse paid = company.pay(created.id(), principal(MOBICOM, Role.COMPANY));
        assertThat(paid.payment().amount())
                .as("only P is charged, not the full B").isEqualTo(999_570.0);
    }

    @Test
    void pricing_errors_are_400_with_the_Mongolian_message_and_nothing_is_saved() {
        long before = campaigns.count();
        authAs(MOBICOM, Role.COMPANY);
        var ex = assertFailsWithHttp(() -> company.create(
                createReq("Интеграцийн тест", 500.0, 1_000, null), principal(MOBICOM, Role.COMPANY)));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(ex.reason())
                .isEqualTo("Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү");
        assertThat(campaigns.count()).isEqualTo(before);
    }

    @Test
    void new_campaigns_use_the_commission_the_admin_set() {
        authAs(ADMIN, Role.ADMIN);
        settings.update(new UpdatePlatformSettingsReq(35, 100), principal(ADMIN, Role.ADMIN));
        try {
            CampaignDto created = createAsMobiCom(createReq("Интеграцийн тест", 500_000.0, 1_000, null));
            assertThat(created.costPerView()).isEqualTo(500.0);
            assertThat(created.rewardPerUser()).isEqualTo(325.0);
            assertThat(created.commissionPercent()).isEqualTo(35);
        } finally {
            authAs(ADMIN, Role.ADMIN);
            settings.update(new UpdatePlatformSettingsReq(30, 100), principal(ADMIN, Role.ADMIN));
        }
    }

    // --- HTTP contract (JSON shapes the admin panel relies on) --------------

    @Test
    void HTTP_settings_create_pay_payments_round_trip_with_real_JWTs() throws Exception {
        mvc.perform(get("/platform-settings"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.commissionPercent").value(30))
                .andExpect(jsonPath("$.minRewardPerViewer").value(100))
                .andExpect(jsonPath("$.updatedAt").exists())
                .andExpect(jsonPath("$.surveyOnlyCostPerResponse").doesNotExist());

        String createdJson = mvc.perform(post("/company/campaigns")
                        .header("Authorization", bearer(MOBICOM))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"title":"HTTP аян","hasVideo":false,"totalBudget":1000000,"rewardPerUser":700,
                                 "costPerView":5,
                                 "questions":[{"prompt":"Асуулт?","type":"TEXT"}]}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("AWAITING_PAYMENT"))
                .andExpect(jsonPath("$.targetViewers").value(1000))
                .andExpect(jsonPath("$.costPerView").value(1000.0))
                .andExpect(jsonPath("$.rewardPerUser").value(700.0))
                .andExpect(jsonPath("$.totalBudget").value(1_000_000.0))
                .andExpect(jsonPath("$.commissionPercent").value(30))
                .andExpect(jsonPath("$.paidAt").value(nullValue()))
                .andReturn().getResponse().getContentAsString();
        long id = json.readTree(createdJson).get("id").asLong();

        mvc.perform(post("/company/campaigns")
                        .header("Authorization", bearer(MOBICOM))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\",\"durationSeconds\":30,\"totalBudget\":1000000,"
                                + "\"targetViewers\":10,\"rewardPerUser\":700}"))
                .andExpect(status().isBadRequest())
                .andExpect(status().reason(CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE));

        mvc.perform(post("/company/campaigns/" + id + "/pay").header("Authorization", bearer(GOLOMT)))
                .andExpect(status().isForbidden());

        mvc.perform(post("/company/campaigns/" + id + "/pay").header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.campaign.status").value("PENDING"))
                .andExpect(jsonPath("$.campaign.paidAt").exists())
                .andExpect(jsonPath("$.payment.campaignId").value(id))
                .andExpect(jsonPath("$.payment.campaignTitle").value("HTTP аян"))
                .andExpect(jsonPath("$.payment.amount").value(1_000_000.0))
                .andExpect(jsonPath("$.payment.provider").value("SIMULATED"))
                .andExpect(jsonPath("$.payment.status").value("PAID"))
                .andExpect(jsonPath("$.payment.reference").value(matchesPattern("UZ-\\d{8}-" + id)))
                .andExpect(jsonPath("$.payment.createdAt").exists())
                .andExpect(jsonPath("$.payment.paidAt").exists());

        mvc.perform(post("/company/campaigns/" + id + "/pay").header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isConflict())
                .andExpect(status().reason(CompanyMessages.NOT_PAYABLE_MESSAGE));

        mvc.perform(get("/company/payments").header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].campaignId").value(id));
        mvc.perform(get("/company/payments").header("Authorization", bearer(VIEWER)))
                .andExpect(status().isForbidden());

        mvc.perform(patch("/company/campaigns/" + id + "/status?status=ACTIVE")
                        .header("Authorization", bearer(MOBICOM)))
                .andExpect(status().isConflict())
                .andExpect(status().reason("Энэ төлөвөөс шилжих боломжгүй"));

        mvc.perform(patch("/admin/platform-settings")
                        .header("Authorization", bearer(MOBICOM))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"commissionPercent\":40,\"minRewardPerViewer\":100}"))
                .andExpect(status().isForbidden());

        mvc.perform(patch("/admin/platform-settings")
                        .header("Authorization", bearer(ADMIN))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"commissionPercent\":95,\"minRewardPerViewer\":100}"))
                .andExpect(status().isBadRequest())
                .andExpect(status().reason(PlatformSettingsServiceImpl.COMMISSION_RANGE_MESSAGE));
        assertThat(settings.get().commissionPercent()).isEqualTo(30);
    }

    // --- races ---------------------------------------------------------------

    @Test
    void concurrent_double_pay_exactly_one_wins_exactly_one_PAID_row() throws Exception {
        int threads = 4;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        try {
            for (int round = 0; round < 5; round++) {
                CampaignDto created = createAsMobiCom(createReq("race-" + round, 1_000_000.0, 1_000, null));
                long id = created.id();
                CyclicBarrier barrier = new CyclicBarrier(threads);
                List<Future<String>> futures = new ArrayList<>();
                for (int t = 0; t < threads; t++) {
                    Callable<String> task = () -> {
                        authAs(MOBICOM, Role.COMPANY);
                        try {
                            barrier.await(10, TimeUnit.SECONDS);
                            company.pay(id, principal(MOBICOM, Role.COMPANY));
                            return "ok";
                        } catch (DomainException e) {
                            return String.valueOf(ApiExceptionHandler.statusOf(e).value());
                        } finally {
                            SecurityContextHolder.clearContext();
                        }
                    };
                    futures.add(pool.submit(task));
                }
                List<String> results = new ArrayList<>();
                for (Future<String> f : futures) {
                    results.add(f.get(30, TimeUnit.SECONDS));
                }

                assertThat(results.stream().filter("ok"::equals).count())
                        .as("round %d: %s", round, results).isEqualTo(1);
                assertThat(results.stream().filter("409"::equals).count())
                        .as("round %d: %s", round, results).isEqualTo(threads - 1);
                assertThat(paidRows(id)).as("round %d", round).isEqualTo(1);
                assertThat(campaigns.findById(id).orElseThrow().getStatus()).isEqualTo(CampaignStatus.PENDING);
            }
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void the_partial_unique_index_rejects_a_second_PAID_row_even_if_the_app_is_bypassed() {
        CampaignDto created = createAsMobiCom(createReq());
        long id = created.id();
        company.pay(id, principal(MOBICOM, Role.COMPANY));
        assertThatThrownBy(() -> jdbc.update("""
                INSERT INTO campaign_payments (campaign_id, company_id, amount, provider, status, reference)
                VALUES (?, ?, 1, 'SIMULATED', 'PAID', ?)""",
                id, MOBICOM, "UZ-X-" + id))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThat(paidRows(id)).isEqualTo(1);
    }
}
