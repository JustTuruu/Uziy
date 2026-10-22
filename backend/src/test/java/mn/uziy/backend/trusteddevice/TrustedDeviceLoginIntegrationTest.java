package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.UUID;
import mn.uziy.backend.security.AbstractApiIntegrationTest;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

/**
 * "Ask for the phone only on an unrecognised browser" (owner, 2026-10-22) over real HTTP and Postgres with the
 * simulated provider: after one SMS a console account's browser holds a device token, and the next logins with it
 * (and the right password) are 200 at once. Anything else — another account's token, an expired or garbage one, one
 * from before a password change or an admin's "forget" — is simply the SMS step again (202), with nothing said about
 * why.
 */
class TrustedDeviceLoginIntegrationTest extends AbstractApiIntegrationTest {

    private static final String CHROME = "Mozilla/5.0 (Macintosh) AppleWebKit/537.36 Chrome/141.0 Safari/537.36";

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).header(HttpHeaders.USER_AGENT, CHROME)
                .content(body));
    }

    private ResultActions login(String phone, String password, @Nullable String deviceToken) throws Exception {
        String device = deviceToken == null ? "" : ",\"deviceToken\":\"" + deviceToken + "\"";
        return json("/auth/login",
                "{\"phoneNumber\":\"%s\",\"password\":\"%s\"%s}".formatted(phone, password, device));
    }

    private long account(String role) {
        return "ADMIN".equals(role) ? admin() : company();
    }

    private long phoneChecks(String phone) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM phone_verifications WHERE phone_number = ?", Long.class,
                phone);
    }

    /** Moves the account's last check past the 60 s SMS cool-down, so the next login may open a new one. */
    private void coolDownPasses(String phone) {
        jdbc.update("UPDATE phone_verifications SET created_at = created_at - INTERVAL '2 minutes' "
                + "WHERE phone_number = ?", phone);
    }

    /** The whole first login on a new browser: password, the SMS "arrives", verify. Returns the verify answer. */
    private String firstLogin(String phone) throws Exception {
        String challenge = login(phone, PASSWORD, null).andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
        String id = JsonPath.read(challenge, "$.twoStep.verificationId");
        String session = jdbc.queryForObject("SELECT provider_session_id FROM phone_verifications WHERE id = ?",
                String.class, UUID.fromString(id));
        mvc.perform(post("/auth/phone-verifications/simulated-sms/" + session)).andExpect(status().isNoContent());
        String body = json("/auth/login/verify",
                "{\"phoneNumber\":\"%s\",\"verificationId\":\"%s\"}".formatted(phone, id))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        coolDownPasses(phone);
        return body;
    }

    private String deviceTokenOf(String phone) throws Exception {
        return JsonPath.read(firstLogin(phone), "$.deviceToken");
    }

    @ParameterizedTest
    @ValueSource(strings = {"ADMIN", "COMPANY"})
    void theSmsStepGivesTheBrowserADeviceTokenTrustedForThirtyDays(String role) throws Exception {
        long user = account(role);
        String body = firstLogin(phoneOf(user));

        String deviceToken = JsonPath.read(body, "$.deviceToken");
        OffsetDateTime until = OffsetDateTime.parse(JsonPath.read(body, "$.deviceTrustedUntil"));
        assertThat(deviceToken).matches("[A-Za-z0-9_-]{43}");
        assertThat(Duration.between(OffsetDateTime.now(), until)).isBetween(Duration.ofDays(29), Duration.ofDays(30));
        assertThat(jdbc.queryForObject("SELECT token_hash FROM trusted_devices WHERE user_id = ?", String.class, user))
                .isEqualTo(DeviceSecrets.hash(deviceToken)).isNotEqualTo(deviceToken);
        assertThat(jdbc.queryForObject("SELECT label FROM trusted_devices WHERE user_id = ?", String.class, user))
                .isEqualTo("Chrome");
    }

    @ParameterizedTest
    @ValueSource(strings = {"ADMIN", "COMPANY"})
    void theNextLoginFromThatBrowserIsSignedInWithoutAnSms(String role) throws Exception {
        long user = account(role);
        String phone = phoneOf(user);
        String deviceToken = deviceTokenOf(phone);
        long checksBefore = phoneChecks(phone);

        String body = login(phone, PASSWORD, deviceToken).andExpect(status().isOk())
                .andExpect(jsonPath("$.user.id").value(user))
                .andExpect(jsonPath("$.user.role").value(role))
                .andExpect(jsonPath("$.twoStep").doesNotExist())
                .andExpect(jsonPath("$.deviceToken").doesNotExist())
                .andReturn().getResponse().getContentAsString();

        assertThat(phoneChecks(phone)).isEqualTo(checksBefore);
        String token = JsonPath.read(body, "$.token");
        String home = "ADMIN".equals(role) ? "/admin/stats" : "/company/campaigns";
        mvc.perform(get(home).header("Authorization", "Bearer " + token)).andExpect(status().isOk());
    }

    @Test
    void aRememberedBrowserStillNeedsTheRightPassword() throws Exception {
        String phone = phoneOf(company());
        String deviceToken = deviceTokenOf(phone);

        login(phone, "wrong-password", deviceToken).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.token").doesNotExist());
    }

    @Test
    void anotherAccountsDeviceTokenOnlyGetsTheSmsStep() throws Exception {
        String mine = phoneOf(company());
        String theirs = deviceTokenOf(phoneOf(company()));

        login(mine, PASSWORD, theirs).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.twoStep.verificationId").isNotEmpty());
    }

    @Test
    void anExpiredDeviceTokenOnlyGetsTheSmsStep() throws Exception {
        long company = company();
        String phone = phoneOf(company);
        String deviceToken = deviceTokenOf(phone);
        jdbc.update("UPDATE trusted_devices SET expires_at = now() - INTERVAL '1 second' WHERE user_id = ?", company);

        login(phone, PASSWORD, deviceToken).andExpect(status().isAccepted());
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "garbage", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", "%27%3B--", "x\\\"y"})
    void aGarbageDeviceTokenIsJustAnUnknownBrowser(String deviceToken) throws Exception {
        String phone = phoneOf(company());

        login(phone, PASSWORD, deviceToken).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.twoStep.verificationId").isNotEmpty());
    }

    @Test
    void anOverlongDeviceTokenIsJustAnUnknownBrowser() throws Exception {
        String phone = phoneOf(company());

        login(phone, PASSWORD, "A".repeat(10_000)).andExpect(status().isAccepted());
    }

    @Test
    void theAnswerIsTheSameWhateverWasWrongWithTheDeviceToken() throws Exception {
        String a = phoneOf(company());
        String b = phoneOf(company());
        String foreign = deviceTokenOf(phoneOf(company()));

        String garbage = login(a, PASSWORD, "garbage").andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();
        String stolen = login(b, PASSWORD, foreign).andExpect(status().isAccepted())
                .andReturn().getResponse().getContentAsString();

        assertThat(JsonPath.<java.util.Map<String, Object>>read(garbage, "$.twoStep").keySet())
                .isEqualTo(JsonPath.<java.util.Map<String, Object>>read(stolen, "$.twoStep").keySet());
    }

    /** A password change (any path: reset, the admin tool) leaves old browsers strangers even if a row stayed. */
    @Test
    void aPasswordChangeMakesTheOldDeviceTokenAskForTheSmsAgain() throws Exception {
        long company = company();
        String phone = phoneOf(company);
        String deviceToken = deviceTokenOf(phone);
        jdbc.update("UPDATE users SET credentials_changed_at = now() WHERE id = ?", company);

        login(phone, PASSWORD, deviceToken).andExpect(status().isAccepted());
    }

    @Test
    void aNewSmsStepGivesANewTokenAndTheOldBrowserIsStillRemembered() throws Exception {
        String phone = phoneOf(company());
        String first = deviceTokenOf(phone);
        String second = deviceTokenOf(phone);

        assertThat(second).isNotEqualTo(first);
        login(phone, PASSWORD, first).andExpect(status().isOk());
        login(phone, PASSWORD, second).andExpect(status().isOk());
    }

    @Test
    void anAdminCanForgetACompanysBrowsers() throws Exception {
        long company = company();
        String phone = phoneOf(company);
        String deviceToken = deviceTokenOf(phone);

        mvc.perform(post("/admin/users/" + company + "/trusted-devices/forget").header("Authorization", bearer(admin())))
                .andExpect(status().isNoContent());

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM trusted_devices WHERE user_id = ?", Long.class, company))
                .isZero();
        login(phone, PASSWORD, deviceToken).andExpect(status().isAccepted());
    }

    @Test
    void forgettingAnUnknownAccountIs404() throws Exception {
        mvc.perform(post("/admin/users/999999999/trusted-devices/forget").header("Authorization", bearer(admin())))
                .andExpect(status().isNotFound());
    }

    @Test
    void onlyAnAdminMayForgetBrowsers() throws Exception {
        long company = company();

        mvc.perform(post("/admin/users/" + company + "/trusted-devices/forget").header("Authorization",
                bearer(company))).andExpect(status().isForbidden());
    }

    @Test
    void aViewersLoginIgnoresADeviceToken() throws Exception {
        long viewer = viewer(0);
        String phone = phoneOf(viewer);

        login(phone, PASSWORD, "garbage").andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.id").value(viewer));
        login(phone, PASSWORD, null).andExpect(status().isOk());
        assertThat(phoneChecks(phone)).isZero();
    }
}
