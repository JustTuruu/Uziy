package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import mn.uziy.backend.phoneverify.PhoneVerificationService;
import mn.uziy.backend.phoneverify.PhoneVerificationStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * A forgotten password over real HTTP, security and Postgres, proved the verify.mn way (the viewer texts a
 * code): reset works once, logs in with the new password, refuses an unknown phone before any SMS, and never
 * accepts a check opened for registration. Reuses the scripted provider of PhoneVerificationFlowIntegrationTest;
 * each test uses its own phone number.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@Import(PhoneVerificationFlowIntegrationTest.ScriptedProvider.class)
class PasswordResetFlowIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_password_reset_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired PhoneVerificationFlowIntegrationTest.Script script;
    @Autowired JdbcTemplate jdbc;

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions startCheck(String phone, String purpose) throws Exception {
        return json("/auth/phone-verifications",
                "{\"phoneNumber\":\"%s\",\"purpose\":\"%s\"}".formatted(phone, purpose));
    }

    private String verifiedCheck(String phone, String purpose) throws Exception {
        String body = startCheck(phone, purpose).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        script.byPhone.put(phone, PhoneVerificationStatus.VERIFIED);
        return JsonPath.read(body, "$.verificationId");
    }

    /** A viewer with password "oldpass1"; the registration check is moved past the per-phone cool-down. */
    private void viewer(String phone) throws Exception {
        String id = verifiedCheck(phone, "REGISTER");
        json("/auth/register/viewer", """
                {"phoneNumber":"%s","password":"oldpass1","lastName":"Бат","firstName":"Болд","gender":"MALE",
                 "birthDate":"2000-01-01","city":"Улаанбаатар","verificationId":"%s"}""".formatted(phone, id))
                .andExpect(status().isCreated());
        script.byPhone.remove(phone);
        jdbc.update("UPDATE phone_verifications SET created_at = created_at - INTERVAL '2 minutes' "
                + "WHERE phone_number = ?", phone);
    }

    private ResultActions reset(String phone, String verificationId, String newPassword) throws Exception {
        return json("/auth/password/reset", """
                {"phoneNumber":"%s","verificationId":"%s","newPassword":"%s"}"""
                .formatted(phone, verificationId, newPassword));
    }

    private ResultActions login(String phone, String password) throws Exception {
        return json("/auth/login", "{\"phoneNumber\":\"%s\",\"password\":\"%s\"}".formatted(phone, password));
    }

    @Test
    void aViewerWhoTextsTheCodeSetsANewPasswordAndLogsInWithIt() throws Exception {
        String phone = "72000001";
        viewer(phone);
        String id = verifiedCheck(phone, "PASSWORD_RESET");

        reset(phone, id, "newpass1").andExpect(status().isNoContent());

        login(phone, "newpass1").andExpect(status().isOk());
        login(phone, "oldpass1").andExpect(status().isUnauthorized());
    }

    @Test
    void aResetIsRefusedUntilTheSmsArrived() throws Exception {
        String phone = "72000002";
        viewer(phone);
        String body = startCheck(phone, "PASSWORD_RESET").andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        String id = JsonPath.read(body, "$.verificationId");

        reset(phone, id, "newpass1").andExpect(status().isBadRequest());
        login(phone, "oldpass1").andExpect(status().isOk());
    }

    @Test
    void aResetCheckWorksOnlyOnce() throws Exception {
        String phone = "72000003";
        viewer(phone);
        String id = verifiedCheck(phone, "PASSWORD_RESET");

        reset(phone, id, "newpass1").andExpect(status().isNoContent());
        reset(phone, id, "another1").andExpect(status().isBadRequest());
        login(phone, "newpass1").andExpect(status().isOk());
    }

    @Test
    void aPhoneWithoutAnAccountIsToldSoBeforeAnySmsIsAskedFor() throws Exception {
        startCheck("72000004", "PASSWORD_RESET")
                .andExpect(status().isNotFound())
                .andExpect(r -> assertThat(r.getResponse().getErrorMessage())
                        .isEqualTo(PhoneVerificationService.ACCOUNT_NOT_FOUND));
    }

    @Test
    void aCheckOpenedToRegisterCannotResetAPassword() throws Exception {
        String phone = "72000005";
        viewer(phone);
        // A second, still unused REGISTER check of the same phone, opened before the account existed.
        String stray = jdbc.queryForObject(
                "SELECT id::text FROM phone_verifications WHERE phone_number = ? LIMIT 1", String.class, phone);
        jdbc.update("UPDATE phone_verifications SET claimed = false WHERE phone_number = ?", phone);

        reset(phone, stray, "newpass1").andExpect(status().isBadRequest());
        login(phone, "oldpass1").andExpect(status().isOk());
    }

    @Test
    void aResetCheckCannotChangeAnotherViewersPassword() throws Exception {
        String mine = "72000006";
        String theirs = "72000007";
        viewer(mine);
        viewer(theirs);
        String id = verifiedCheck(mine, "PASSWORD_RESET");

        reset(theirs, id, "hacked11").andExpect(status().isBadRequest());
        login(theirs, "oldpass1").andExpect(status().isOk());
    }
}
