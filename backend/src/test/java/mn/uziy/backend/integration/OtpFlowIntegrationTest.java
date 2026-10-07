package mn.uziy.backend.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
 * One-time codes over real HTTP, security and Postgres: a viewer cannot register without the code
 * sent to their phone, wrong guesses are counted even though they fail, and a password reset works
 * end to end. Each test uses its own phone number, so the per-phone cool-down never interferes.
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

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private ResultActions requestCode(String phone, OtpPurpose purpose) throws Exception {
        return json("/auth/otp/request", "{\"phoneNumber\":\"%s\",\"purpose\":\"%s\"}".formatted(phone, purpose));
    }

    private ResultActions register(String phone, String password, String code) throws Exception {
        return json("/auth/register/viewer", """
                {"phoneNumber":"%s","password":"%s","gender":"MALE","birthDate":"2000-01-01",
                 "city":"Улаанбаатар","otpCode":"%s"}""".formatted(phone, password, code));
    }

    private ResultActions login(String phone, String password) throws Exception {
        return json("/auth/login", "{\"phoneNumber\":\"%s\",\"password\":\"%s\"}".formatted(phone, password));
    }

    @Test
    void registeringNeedsTheCodeThatWasSentToThePhone() throws Exception {
        String phone = "70000001";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());

        register(phone, "password1", sent.codeFor(phone)).andExpect(status().isCreated());
        login(phone, "password1").andExpect(status().isOk());
    }

    @Test
    void registeringWithoutOrWithAWrongCodeIsRefused() throws Exception {
        String phone = "70000002";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());
        String right = sent.codeFor(phone);
        String wrong = right.equals("000000") ? "000001" : "000000";

        register(phone, "password1", wrong).andExpect(status().isBadRequest());
        login(phone, "password1").andExpect(status().isUnauthorized());
    }

    @Test
    void aCodeCannotRegisterAnotherPhone() throws Exception {
        String phone = "70000003";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());

        register("70000004", "password1", sent.codeFor(phone)).andExpect(status().isBadRequest());
    }

    @Test
    void wrongGuessesAreCountedSoTheRightCodeStopsWorkingAfterTheLimit() throws Exception {
        String phone = "70000005";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());
        String right = sent.codeFor(phone);
        String wrong = right.equals("000000") ? "000001" : "000000";

        for (int i = 0; i < 5; i++) {
            register(phone, "password1", wrong).andExpect(status().isBadRequest());
        }

        // The attempts were saved although every call failed: even the real code is now dead.
        register(phone, "password1", right).andExpect(status().isBadRequest());
    }

    @Test
    void askingForAnotherCodeStraightAwayIsRateLimited() throws Exception {
        String phone = "70000006";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());

        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isTooManyRequests());
    }

    @Test
    void aRegisteredPhoneCannotBeRegisteredAgain() throws Exception {
        String phone = "70000007";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());
        register(phone, "password1", sent.codeFor(phone)).andExpect(status().isCreated());

        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isConflict());
    }

    @Test
    void passwordResetWorksEndToEnd() throws Exception {
        String phone = "70000008";
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());
        register(phone, "old-password", sent.codeFor(phone)).andExpect(status().isCreated());

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
        requestCode(phone, OtpPurpose.REGISTER).andExpect(status().isNoContent());
        register(phone, "old-password", sent.codeFor(phone)).andExpect(status().isCreated());
        requestCode(phone, OtpPurpose.PASSWORD_RESET).andExpect(status().isNoContent());
        String body = """
                {"phoneNumber":"%s","code":"%s","newPassword":"new-password"}"""
                .formatted(phone, sent.codeFor(phone));

        json("/auth/password/reset", body).andExpect(status().isNoContent());
        json("/auth/password/reset", body).andExpect(status().isBadRequest());
    }
}
