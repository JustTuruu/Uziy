package mn.uziy.backend.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;

import com.jayway.jsonpath.JsonPath;
import java.util.Map;
import java.util.UUID;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * {@code DELETE /viewer/me} over real HTTP, security and Postgres. The viewer registers through the simulated phone
 * check (the developer "delivers" the SMS), deletes the account, and then: the password and the old token no longer
 * work, nothing personal is left for statistics or analytics, the counted answers stay, and the same phone can
 * register again. Each test uses its own phone number.
 */
class AccountDeletionIntegrationTest extends AbstractApiIntegrationTest {

    private static final String VIEWER_PASSWORD = "password1";

    private MockHttpServletResponse call(MockHttpServletRequestBuilder request, String token, String json)
            throws Exception {
        if (token != null) {
            request.header("Authorization", "Bearer " + token);
        }
        if (json != null) {
            request.contentType(MediaType.APPLICATION_JSON).content(json);
        }
        return mvc.perform(request).andReturn().getResponse();
    }

    /** Registers {@code phone} the way the app does with the simulated provider; returns the session token. */
    private String register(String phone) throws Exception {
        MockHttpServletResponse started = call(post("/auth/phone-verifications"), null,
                "{\"phoneNumber\":\"" + phone + "\"}");
        assertThat(started.getStatus()).isEqualTo(201);
        String verificationId = JsonPath.read(started.getContentAsString(), "$.verificationId");
        String sessionId = jdbc.queryForObject("SELECT provider_session_id FROM phone_verifications WHERE id = ?",
                String.class, UUID.fromString(verificationId));
        assertThat(call(post("/auth/phone-verifications/simulated-sms/" + sessionId), null, null).getStatus())
                .isEqualTo(204);

        MockHttpServletResponse registered = call(post("/auth/register/viewer"), null, """
                {"phoneNumber":"%s","password":"%s","lastName":"Бат","firstName":"Болд","gender":"FEMALE",
                 "birthDate":"2000-01-01","city":"Улаанбаатар","district":"Баянзүрх","verificationId":"%s"}"""
                .formatted(phone, VIEWER_PASSWORD, verificationId));
        assertThat(registered.getStatus()).isEqualTo(201);
        return JsonPath.read(registered.getContentAsString(), "$.token");
    }

    private long idOf(String phone) {
        return jdbc.queryForObject("SELECT id FROM users WHERE phone_number = ?", Long.class, phone);
    }

    private int deleteAccount(String token, String password) throws Exception {
        return call(delete("/viewer/me"), token, "{\"password\":\"" + password + "\"}").getStatus();
    }

    private int login(String phone) throws Exception {
        return call(post("/auth/login"), null,
                "{\"phoneNumber\":\"" + phone + "\",\"password\":\"" + VIEWER_PASSWORD + "\"}").getStatus();
    }

    /** One completed survey: a choice answer and a free-text answer. Returns the view id. */
    private long answeredSurvey(long viewerId) {
        long campaign = activeCampaign(company());
        long choice = question(campaign, 1, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]", true);
        long text = question(campaign, 2, "TEXT", "[]", false);
        long view = jdbc.queryForObject("INSERT INTO view_history (user_id, campaign_id, reward_paid) "
                + "VALUES (?, ?, 70) RETURNING id", Long.class, viewerId, campaign);
        jdbc.update("INSERT INTO survey_responses (view_id, question_id, answer_json) VALUES "
                + "(?, ?, CAST('\"Тийм\"' AS jsonb)), (?, ?, CAST('\"Миний нэр Болд\"' AS jsonb))",
                view, choice, view, text);
        return view;
    }

    @Test
    void afterDeletionNothingPersonalIsLeftAndNeitherThePasswordNorTheOldTokenWork() throws Exception {
        String phone = freshPhone();
        String token = register(phone);
        long id = idOf(phone);
        assertThat(call(put("/viewer/consents/statistics"), token, "{\"granted\":true}").getStatus()).isEqualTo(200);
        jdbc.update("UPDATE users SET balance = 1234 WHERE id = ?", id);
        jdbc.update("INSERT INTO device_tokens (user_id, token, platform) VALUES (?, ?, 'IOS')",
                id, "push-" + phone);
        jdbc.update("INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name, status) "
                + "VALUES (?, 5000, 'Хаан банк', '5012345678', 'Бат Болд', 'APPROVED')", id);
        long view = answeredSurvey(id);

        assertThat(deleteAccount(token, "wrong-password")).isEqualTo(400);
        assertThat(deleteAccount(token, VIEWER_PASSWORD)).isEqualTo(204);

        assertThat(login(phone)).isEqualTo(401);
        assertThat(call(get("/viewer/me"), token, null).getStatus()).isIn(401, 403);

        Map<String, Object> row = jdbc.queryForMap("SELECT * FROM users WHERE id = ?", id);
        assertThat(row.get("phone_number")).isEqualTo("DEL-" + id);
        for (String personal : new String[] {"gender", "birth_date", "city", "district", "last_name", "first_name",
                "stats_consent", "stats_consent_at", "stats_consent_version"}) {
            assertThat(row.get(personal)).as(personal).isNull();
        }
        assertThat(((Number) row.get("balance")).doubleValue()).isZero();
        assertThat(encoder.matches(VIEWER_PASSWORD, (String) row.get("password_hash"))).isFalse();

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens WHERE user_id = ?", Integer.class, id))
                .isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM phone_verifications WHERE phone_number = ?",
                Integer.class, phone)).isZero();
        assertThat(jdbc.queryForList("SELECT CAST(answer_json AS text) FROM survey_responses WHERE view_id = ?",
                String.class, view)).containsExactly("\"Тийм\"");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM view_history WHERE id = ?", Integer.class, view))
                .isEqualTo(1);
        assertThat(jdbc.queryForMap("SELECT account_name, account_number, amount FROM payout_requests "
                + "WHERE user_id = ?", id))
                .containsEntry("account_name", "")
                .containsEntry("account_number", "••••5678")
                .containsEntry("amount", 5000.0);
    }

    @Test
    void statisticsAndCompanyAnalyticsNoLongerSeeThePerson() throws Exception {
        String phone = freshPhone();
        String token = register(phone);
        long id = idOf(phone);
        call(put("/viewer/consents/statistics"), token, "{\"granted\":true}");
        answeredSurvey(id);

        assertThat(deleteAccount(token, VIEWER_PASSWORD)).isEqualTo(204);

        assertThat(jdbc.queryForObject("""
                SELECT COUNT(*) FROM users u
                WHERE u.id = ? AND (u.stats_consent IS NOT NULL OR u.gender IS NOT NULL
                    OR u.birth_date IS NOT NULL OR u.city IS NOT NULL)""", Integer.class, id)).isZero();
        assertThat(jdbc.queryForObject("""
                SELECT COUNT(*) FROM view_history vh JOIN users u ON u.id = vh.user_id
                WHERE vh.user_id = ? AND (u.gender IS NOT NULL OR u.birth_date IS NOT NULL OR u.city IS NOT NULL)""",
                Integer.class, id)).isZero();
    }

    @Test
    void theSamePhoneCanRegisterAgainAfterDeletion() throws Exception {
        String phone = freshPhone();
        String token = register(phone);
        assertThat(deleteAccount(token, VIEWER_PASSWORD)).isEqualTo(204);

        String again = register(phone);

        assertThat(call(get("/viewer/me"), again, null).getStatus()).isEqualTo(200);
        assertThat(login(phone)).isEqualTo(200);
    }

    @Test
    void aPendingPayoutBlocksDeletionAndLeavesTheAccountAsItWas() throws Exception {
        String phone = freshPhone();
        String token = register(phone);
        long id = idOf(phone);
        jdbc.update("INSERT INTO payout_requests (user_id, amount, bank, account_number, account_name) "
                + "VALUES (?, 5000, 'Хаан банк', '5012345678', 'Бат Болд')", id);

        MockHttpServletResponse refused = call(delete("/viewer/me"), token,
                "{\"password\":\"" + VIEWER_PASSWORD + "\"}");

        assertThat(refused.getStatus()).isEqualTo(409);
        assertThat(refused.getErrorMessage()).isEqualTo(AccountDeletionMessages.PAYOUT_PENDING);
        assertThat(phoneOf(id)).isEqualTo(phone);
        assertThat(call(get("/viewer/me"), token, null).getStatus()).isEqualTo(200);
    }
}
