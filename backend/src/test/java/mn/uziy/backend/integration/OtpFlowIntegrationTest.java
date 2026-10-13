package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.otp.OtpPurpose;
import mn.uziy.backend.otp.OtpSender;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Password-reset codes over real HTTP, security and Postgres: a reset works end to end, a code works once, and
 * an unknown phone is answered the same without anything being sent. Each test uses its own phone number, so
 * the per-phone cool-down never interferes. (Registration is covered by PhoneVerificationFlowIntegrationTest.)
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@Import(OtpFlowIntegrationTest.CapturingSender.class)
class OtpFlowIntegrationTest {

    /** Records what would have been texted, so the test can read the code. */
    static class Sent {
        final List<String[]> messages = new ArrayList<>();

        String codeFor(String phone) {
            return messages.stream().filter(m -> m[0].equals(phone)).reduce((a, b) -> b).orElseThrow()[1];
        }

        boolean sentTo(String phone) {
            return messages.stream().anyMatch(m -> m[0].equals(phone));
        }
    }

    @TestConfiguration
    static class CapturingSender {
        @Bean
        Sent sent() {
            return new Sent();
        }

        @Bean
        @Primary
        OtpSender capturingOtpSender(Sent sent) {
            return (phone, code, purpose) -> sent.messages.add(new String[] {phone, code});
        }
    }

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_otp_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired Sent sent;
    @Autowired org.springframework.jdbc.core.JdbcTemplate jdbc;

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions requestCode(String phone, OtpPurpose purpose) throws Exception {
        return json("/auth/otp/request", "{\"phoneNumber\":\"%s\",\"purpose\":\"%s\"}".formatted(phone, purpose));
    }

    /** Registers through the simulated phone verification, pretending the user's SMS arrived. */
    private ResultActions register(String phone, String password) throws Exception {
        String started = json("/auth/phone-verifications", "{\"phoneNumber\":\"%s\"}".formatted(phone))
                .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
        String verificationId = JsonPath.read(started, "$.verificationId");
        String sessionId = jdbc.queryForObject("SELECT provider_session_id FROM phone_verifications WHERE id = ?",
                String.class, java.util.UUID.fromString(verificationId));
        mvc.perform(post("/auth/phone-verifications/simulated-sms/" + sessionId)).andExpect(status().isNoContent());
        return json("/auth/register/viewer", """
                {"phoneNumber":"%s","password":"%s","gender":"MALE","birthDate":"2000-01-01",
                 "city":"Улаанбаатар","verificationId":"%s"}""".formatted(phone, password, verificationId));
    }

    private ResultActions login(String phone, String password) throws Exception {
        return json("/auth/login", "{\"phoneNumber\":\"%s\",\"password\":\"%s\"}".formatted(phone, password));
    }

    @Test
    void passwordResetWorksEndToEnd() throws Exception {
        String phone = "70000008";
        register(phone, "old-password").andExpect(status().isCreated());

        requestCode(phone, OtpPurpose.PASSWORD_RESET).andExpect(status().isNoContent());
        json("/auth/password/reset", """
                {"phoneNumber":"%s","code":"%s","newPassword":"new-password"}"""
                .formatted(phone, sent.codeFor(phone))).andExpect(status().isNoContent());

        login(phone, "new-password").andExpect(status().isOk());
        login(phone, "old-password").andExpect(status().isUnauthorized());
    }

    @Test
    void passwordResetForAnUnknownPhoneAnswersTheSameAndSendsNothing() throws Exception {
        String phone = "70000009";

        requestCode(phone, OtpPurpose.PASSWORD_RESET).andExpect(status().isNoContent());

        assertThat(sent.sentTo(phone)).isFalse();
    }

    @Test
    void aResetCodeCannotBeUsedTwice() throws Exception {
        String phone = "70000010";
        register(phone, "old-password").andExpect(status().isCreated());
        requestCode(phone, OtpPurpose.PASSWORD_RESET).andExpect(status().isNoContent());
        String body = """
                {"phoneNumber":"%s","code":"%s","newPassword":"new-password"}"""
                .formatted(phone, sent.codeFor(phone));

        json("/auth/password/reset", body).andExpect(status().isNoContent());
        json("/auth/password/reset", body).andExpect(status().isBadRequest());
    }
}
