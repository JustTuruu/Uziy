package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * The analytics SQL against a real Postgres, through real HTTP security. Builds its own company
 * with one campaign, six viewers and their answers, so it neither depends on nor disturbs the dev seed.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class AnalyticsIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_analytics_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired JdbcTemplate jdbc;
    @Autowired JwtService jwt;
    @Autowired UserRepository users;

    private static long company;
    private static long campaign;
    private static long otherCompany;
    private static long singleChoice;

    private long insertUser(String phone, String role, String gender, String birth, String city, String name) {
        return jdbc.queryForObject("""
                INSERT INTO users (phone_number, password_hash, role, gender, birth_date, city, company_name)
                VALUES (?, 'x', ?, ?, CAST(? AS date), ?, ?) RETURNING id""",
                Long.class, phone, role, gender, birth, city, name);
    }

    @BeforeAll
    static void noop() {
    }

    /** Idempotent fixture: every test calls it, only the first one inserts. */
    private synchronized void fixture() {
        if (campaign != 0) {
            return;
        }
        company = insertUser("70100001", "COMPANY", null, null, null, "AnalyticsCo");
        otherCompany = insertUser("70100002", "COMPANY", null, null, null, "OtherCo");
        campaign = jdbc.queryForObject("""
                INSERT INTO campaigns (company_id, title, duration_seconds, total_budget, remaining_budget,
                    cost_per_view, reward_per_user, status, target_viewers, paid_at)
                VALUES (?, 'A', 30, 10000, 4000, 1000, 700, 'ACTIVE', 10, NOW()) RETURNING id""",
                Long.class, company);
        singleChoice = jdbc.queryForObject("""
                INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json)
                VALUES (?, 1, 'Like it?', 'SINGLE_CHOICE', '["Yes","No"]'::jsonb) RETURNING id""",
                Long.class, campaign);

        String[][] viewers = {
                {"70200001", "MALE", "2000-01-01", "Улаанбаатар"},
                {"70200002", "MALE", "2001-01-01", "Улаанбаатар"},
                {"70200003", "FEMALE", "1990-01-01", "Дархан"},
                {"70200004", "FEMALE", "1975-01-01", "Улаанбаатар"},
                {"70200005", "FEMALE", "2000-06-01", "Дархан"},
                {"70200006", "MALE", "1998-01-01", "Эрдэнэт"},
        };
        List<Long> viewIds = new ArrayList<>();
        for (String[] v : viewers) {
            long viewer = insertUser(v[0], "VIEWER", v[1], v[2], v[3], null);
            viewIds.add(jdbc.queryForObject("""
                    INSERT INTO view_history (user_id, campaign_id, reward_paid, watched_at)
                    VALUES (?, ?, 700, NOW()) RETURNING id""", Long.class, viewer, campaign));
        }
        for (int i = 0; i < viewIds.size(); i++) {
            jdbc.update("""
                    INSERT INTO survey_responses (view_id, question_id, answer_json)
                    VALUES (?, ?, CAST(? AS jsonb))""",
                    viewIds.get(i), singleChoice, i < 4 ? "\"Yes\"" : "\"No\"");
        }
    }

    private String bearer(long userId) {
        return "Bearer " + jwt.issue(users.findById(userId).orElseThrow());
    }

    @Test
    void anAnonymousCallerIsRefused() throws Exception {
        mvc.perform(get("/company/analytics")).andExpect(status().is4xxClientError());
    }

    @Test
    void theReportCountsRealViewsRewardsAndSpend() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").header("Authorization", bearer(company)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totals.responses").value(6))
                .andExpect(jsonPath("$.totals.rewardsPaid").value(4200.0))
                .andExpect(jsonPath("$.totals.spent").value(6000.0))
                .andExpect(jsonPath("$.totals.costPerResponse").value(1000.0))
                .andExpect(jsonPath("$.campaigns", hasSize(1)))
                .andExpect(jsonPath("$.campaigns[0].responses").value(6))
                .andExpect(jsonPath("$.campaigns[0].reachPercent").value(60.0));
    }

    @Test
    void todaysViewsLandOnTheLastDayOfTheSeries() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").param("days", "7").header("Authorization", bearer(company)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.daily", hasSize(7)))
                .andExpect(jsonPath("$.daily[6].responses").value(6))
                .andExpect(jsonPath("$.daily[0].responses").value(0));
    }

    /** 6 responses: 3 men / 3 women, 4·1·1 per age band, 3·2·1 per city — every slice is under 5 people. */
    @Test
    void theAudienceHidesEverySliceOfFewerThanFivePeople() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").header("Authorization", bearer(company)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.audience.gender", hasSize(0)))
                .andExpect(jsonPath("$.audience.ageBands[?(@.count > 0)]", hasSize(0)))
                .andExpect(jsonPath("$.audience.cities", hasSize(0)));
    }

    @Test
    void selectingACampaignAddsTheAnswerBreakdown() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").param("campaignId", String.valueOf(campaign))
                        .header("Authorization", bearer(company)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.questions", hasSize(1)))
                .andExpect(jsonPath("$.questions[0].answered").value(6))
                .andExpect(jsonPath("$.questions[0].options[0].label").value("Yes"))
                .andExpect(jsonPath("$.questions[0].options[0].count").value(4))
                .andExpect(jsonPath("$.questions[0].options[1].count").value(2));
    }

    @Test
    void answersCanBeComparedAcrossSegmentsOnceEachIsBigEnough() throws Exception {
        long segCo = insertUser("70300001", "COMPANY", null, null, null, "SegCo");
        long segCampaign = jdbc.queryForObject("""
                INSERT INTO campaigns (company_id, title, duration_seconds, total_budget, remaining_budget,
                    cost_per_view, reward_per_user, status, target_viewers, paid_at)
                VALUES (?, 'S', 30, 10000, 0, 1000, 700, 'ACTIVE', 10, NOW()) RETURNING id""",
                Long.class, segCo);
        long question = jdbc.queryForObject("""
                INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json)
                VALUES (?, 1, 'Like it?', 'SINGLE_CHOICE', '["Yes","No"]'::jsonb) RETURNING id""",
                Long.class, segCampaign);
        for (int i = 0; i < 10; i++) {
            boolean man = i < 5;
            long viewer = insertUser("7040000" + i, "VIEWER", man ? "MALE" : "FEMALE", "2004-01-01", "Улаанбаатар", null);
            long view = jdbc.queryForObject("""
                    INSERT INTO view_history (user_id, campaign_id, reward_paid, watched_at)
                    VALUES (?, ?, 700, NOW()) RETURNING id""", Long.class, viewer, segCampaign);
            jdbc.update("INSERT INTO survey_responses (view_id, question_id, answer_json) VALUES (?, ?, CAST(? AS jsonb))",
                    view, question, man ? "\"Yes\"" : "\"No\"");
        }

        mvc.perform(get("/company/analytics").param("campaignId", String.valueOf(segCampaign))
                        .header("Authorization", bearer(segCo)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.segments", hasSize(1)))
                .andExpect(jsonPath("$.segments[0].segments[0].label").value("MALE"))
                .andExpect(jsonPath("$.segments[0].segments[0].count").value(5))
                .andExpect(jsonPath("$.segments[0].segments[1].label").value("FEMALE"))
                .andExpect(jsonPath("$.segments[0].segments[2].label").value("18–24"))
                .andExpect(jsonPath("$.segments[0].options[0].label").value("Yes"))
                .andExpect(jsonPath("$.segments[0].options[0].counts[0]").value(5))
                .andExpect(jsonPath("$.segments[0].options[0].counts[1]").value(0))
                .andExpect(jsonPath("$.segments[0].options[0].counts[2]").value(5))
                .andExpect(jsonPath("$.audience.gender[?(@.label=='MALE')].count").value(5))
                .andExpect(jsonPath("$.audience.gender[?(@.label=='FEMALE')].count").value(5))
                .andExpect(jsonPath("$.audience.ageBands", hasSize(5)))
                .andExpect(jsonPath("$.audience.ageBands[?(@.label=='18–24')].count").value(10))
                .andExpect(jsonPath("$.audience.cities[0].label").value("Улаанбаатар"))
                .andExpect(jsonPath("$.audience.cities[0].count").value(10));
    }

    @Test
    void segmentsAreWithheldWhenNoSegmentIsBigEnough() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").param("campaignId", String.valueOf(campaign))
                        .header("Authorization", bearer(company)))
                .andExpect(jsonPath("$.segments", hasSize(0)));
    }

    @Test
    void responsesAreCountedByHourOfDayInMarketTime() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").header("Authorization", bearer(company)))
                .andExpect(jsonPath("$.hourly", hasSize(24)))
                .andExpect(jsonPath("$.hourly[*]").value(org.hamcrest.Matchers.hasItem(6)));
    }

    @Test
    void aRunningCampaignGetsItsRemainingResponsesAndPace() throws Exception {
        fixture();

        // remaining 4000 / cost 1000 = 4 left; 6 responses today → 6/7 a day → ceil(4 / (6/7)) = 5 days
        mvc.perform(get("/company/analytics").header("Authorization", bearer(company)))
                .andExpect(jsonPath("$.campaigns[0].remainingResponses").value(4))
                .andExpect(jsonPath("$.campaigns[0].responsesLast7Days").value(6))
                .andExpect(jsonPath("$.campaigns[0].daysLeft").value(5));
    }

    @Test
    void withoutASelectedCampaignThereIsNoBreakdown() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").header("Authorization", bearer(company)))
                .andExpect(jsonPath("$.questions", hasSize(0)));
    }

    @Test
    void anotherCompanySeesNothingOfIt() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").header("Authorization", bearer(otherCompany)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totals.responses").value(0))
                .andExpect(jsonPath("$.campaigns", hasSize(0)))
                .andExpect(jsonPath("$.audience").value(nullValue()));
    }

    @Test
    void anotherCompanysCampaignIdIsNotFound() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").param("campaignId", String.valueOf(campaign))
                        .header("Authorization", bearer(otherCompany)))
                .andExpect(status().isNotFound());
    }

    @Test
    void aWindowOutsideTheAllowedRangeIsABadRequest() throws Exception {
        fixture();

        mvc.perform(get("/company/analytics").param("days", "3").header("Authorization", bearer(company)))
                .andExpect(status().isBadRequest());
        assertThat(campaign).isPositive();
    }
}
