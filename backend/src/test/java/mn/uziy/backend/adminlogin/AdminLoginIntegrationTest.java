package mn.uziy.backend.adminlogin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.UUID;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/**
 * The admin login over real HTTP, security and Postgres with the simulated provider (exactly how a developer logs in
 * locally): the password alone gives no token; the token comes only after an SMS "arrives" for a check the login
 * opened for that admin's phone. Viewers and companies log in as before.
 */
class AdminLoginIntegrationTest extends AbstractApiIntegrationTest {

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions login(String phone, String password) throws Exception {
        return json("/auth/login", "{\"phoneNumber\":\"%s\",\"password\":\"%s\"}".formatted(phone, password));
    }

    private ResultActions verify(String phone, String verificationId) throws Exception {
        return json("/auth/admin/login/verify",
                "{\"phoneNumber\":\"%s\",\"verificationId\":\"%s\"}".formatted(phone, verificationId));
    }

    /** Logs in with the right password and returns the check the login opened. */
    private String passwordStep(String phone) throws Exception {
        String body = login(phone, PASSWORD).andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.twoStep.verificationId");
    }

    /** What the developer does with the curl from the backend log: the admin's SMS "arrives". */
    private void smsArrives(String verificationId) throws Exception {
        String session = jdbc.queryForObject("SELECT provider_session_id FROM phone_verifications WHERE id = ?",
                String.class, UUID.fromString(verificationId));
        mvc.perform(post("/auth/phone-verifications/simulated-sms/" + session)).andExpect(status().isNoContent());
    }

    /** A confirmed, unused check of {@code phone} for {@code purpose}, as if made elsewhere. */
    private String confirmedCheck(String phone, String purpose) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
                INSERT INTO phone_verifications (id, phone_number, purpose, provider_session_id, status, expires_at,
                                                 verified_at, claimed, created_at)
                VALUES (?, ?, ?, 'test', 'VERIFIED', now() + INTERVAL '5 minutes', now(), false, now())""",
                id, phone, purpose);
        return id.toString();
    }

    @Test
    void theRightPasswordGivesAnAdminTheSmsStepButNoToken() throws Exception {
        String phone = phoneOf(admin());

        String body = login(phone, PASSWORD).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.user").doesNotExist())
                .andExpect(jsonPath("$.twoStep.shortcode").value("144773"))
                .andExpect(jsonPath("$.twoStep.phoneNumber").value("•••• " + phone.substring(4)))
                .andExpect(jsonPath("$.twoStep.smsText").isNotEmpty())
                .andExpect(jsonPath("$.twoStep.smsUri").isNotEmpty())
                .andExpect(jsonPath("$.twoStep.displayInstruction").isNotEmpty())
                .andExpect(jsonPath("$.twoStep.expiresAt").isNotEmpty())
                .andReturn().getResponse().getContentAsString();

        String id = JsonPath.read(body, "$.twoStep.verificationId");
        assertThat(jdbc.queryForObject("SELECT purpose FROM phone_verifications WHERE id = ?", String.class,
                UUID.fromString(id))).isEqualTo("ADMIN_LOGIN");
    }

    @Test
    void aWrongAdminPasswordOpensNoSmsCheck() throws Exception {
        String phone = phoneOf(admin());

        login(phone, "wrong-password").andExpect(status().isUnauthorized());

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM phone_verifications WHERE phone_number = ?",
                Long.class, phone)).isZero();
    }

    @Test
    void afterTheSmsTheAdminGetsAWorkingTokenOnce() throws Exception {
        long admin = admin();
        String phone = phoneOf(admin);
        String id = passwordStep(phone);
        verify(phone, id).andExpect(status().isBadRequest()); // no SMS yet

        smsArrives(id);
        mvc.perform(get("/auth/phone-verifications/" + id)).andExpect(jsonPath("$.status").value("VERIFIED"));
        String body = verify(phone, id).andExpect(status().isOk())
                .andExpect(jsonPath("$.user.role").value("ADMIN"))
                .andReturn().getResponse().getContentAsString();

        String token = JsonPath.read(body, "$.token");
        mvc.perform(get("/admin/stats").header("Authorization", "Bearer " + token)).andExpect(status().isOk());
        verify(phone, id).andExpect(status().isBadRequest()); // spent
    }

    @Test
    void aCheckMadeForRegistrationOrAPasswordResetCannotFinishAnAdminLogin() throws Exception {
        String phone = phoneOf(admin());

        verify(phone, confirmedCheck(phone, "REGISTER")).andExpect(status().isBadRequest());
        verify(phone, confirmedCheck(phone, "PASSWORD_RESET")).andExpect(status().isBadRequest());
    }

    @Test
    void anotherAdminsCheckCannotSignYouIn() throws Exception {
        String first = phoneOf(admin());
        String second = phoneOf(admin());
        String id = passwordStep(first);
        smsArrives(id);

        verify(second, id).andExpect(status().isBadRequest());
        verify(first, id).andExpect(status().isOk());
    }

    @Test
    void aViewersPhoneCannotUseTheAdminStepEvenWithAConfirmedCheck() throws Exception {
        String phone = phoneOf(viewer(0));

        verify(phone, confirmedCheck(phone, "ADMIN_LOGIN")).andExpect(status().isBadRequest());
    }

    @Test
    void anUnfinishedLoginRunsOut() throws Exception {
        String phone = phoneOf(admin());
        String id = passwordStep(phone);
        smsArrives(id);
        mvc.perform(get("/auth/phone-verifications/" + id)).andExpect(jsonPath("$.status").value("VERIFIED"));
        jdbc.update("UPDATE phone_verifications SET verified_at = now() - INTERVAL '6 minutes' WHERE id = ?",
                UUID.fromString(id));

        verify(phone, id).andExpect(status().isBadRequest());
    }

    @Test
    void nobodyCanOpenAnAdminLoginCheckThroughThePublicEndpoint() throws Exception {
        String phone = phoneOf(admin());

        json("/auth/phone-verifications", "{\"phoneNumber\":\"%s\",\"purpose\":\"ADMIN_LOGIN\"}".formatted(phone))
                .andExpect(status().isBadRequest());

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM phone_verifications WHERE phone_number = ?",
                Long.class, phone)).isZero();
    }

    @Test
    void viewersAndCompaniesStillGetTheirTokenAtOnce() throws Exception {
        for (long user : new long[] {viewer(0), company()}) {
            login(phoneOf(user), PASSWORD).andExpect(status().isOk())
                    .andExpect(jsonPath("$.token").isNotEmpty())
                    .andExpect(jsonPath("$.user.id").value(user))
                    .andExpect(jsonPath("$.twoStep").doesNotExist());
        }
    }
}
