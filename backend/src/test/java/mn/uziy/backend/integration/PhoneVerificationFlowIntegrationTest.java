package mn.uziy.backend.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import mn.uziy.backend.phoneverify.PhoneVerificationGateway;
import mn.uziy.backend.phoneverify.PhoneVerificationSession;
import mn.uziy.backend.phoneverify.PhoneVerificationStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
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
 * Registration over real HTTP, security and Postgres, with a scripted provider standing in for verify.mn: the
 * app polls PENDING → VERIFIED and only then can register, a check works once and only for its phone, and an
 * expired check cannot register. Each test uses its own phone number.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@Import(PhoneVerificationFlowIntegrationTest.ScriptedProvider.class)
class PhoneVerificationFlowIntegrationTest {

    /** Status per phone, set by the test; unknown phones stay PENDING. */
    static class Script {
        final Map<String, PhoneVerificationStatus> byPhone = new ConcurrentHashMap<>();
    }

    @TestConfiguration
    static class ScriptedProvider {
        @Bean
        Script script() {
            return new Script();
        }

        @Bean
        @Primary
        PhoneVerificationGateway scriptedGateway(Script script, Clock clock) {
            return new PhoneVerificationGateway() {
                @Override
                public PhoneVerificationSession start(String phone, String text) {
                    return new PhoneVerificationSession(phone, "144773", text, "sms:144773?body=" + text,
                            "Та өөрийн " + phone + " дугаараас 144773 дугаарт \"" + text + "\" гэж SMS илгээнэ үү.",
                            OffsetDateTime.now(clock).plusMinutes(5));
                }

                @Override
                public PhoneVerificationStatus status(String sessionId) {
                    return script.byPhone.getOrDefault(sessionId, PhoneVerificationStatus.PENDING);
                }
            };
        }
    }

    @Container
    static final PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("uziy_phone_verify_test")
            .withUsername("test")
            .withPassword("test");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired MockMvc mvc;
    @Autowired Script script;
    @Autowired JdbcTemplate jdbc;

    private ResultActions json(String path, String body) throws Exception {
        return mvc.perform(post(path).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    private String start(String phone) throws Exception {
        String body = json("/auth/phone-verifications", "{\"phoneNumber\":\"%s\"}".formatted(phone))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.smsText").value(org.hamcrest.Matchers.matchesPattern("\\d{6}")))
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andReturn().getResponse().getContentAsString();
        return JsonPath.read(body, "$.verificationId");
    }

    private ResultActions check(String id) throws Exception {
        return mvc.perform(get("/auth/phone-verifications/" + id));
    }

    private ResultActions register(String phone, String verificationId) throws Exception {
        return json("/auth/register/viewer", """
                {"phoneNumber":"%s","password":"password1","lastName":"Бат","firstName":"Болд","gender":"FEMALE","birthDate":"2000-01-01",
                 "city":"Улаанбаатар","district":"Баянзүрх","verificationId":"%s"}""".formatted(phone, verificationId));
    }

    @Test
    void pollingSeesPendingThenVerifiedAndThenTheViewerCanRegister() throws Exception {
        String phone = "71000001";
        String id = start(phone);

        check(id).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("PENDING"));
        register(phone, id).andExpect(status().isBadRequest());

        script.byPhone.put(phone, PhoneVerificationStatus.VERIFIED);
        check(id).andExpect(jsonPath("$.status").value("VERIFIED"));

        register(phone, id).andExpect(status().isCreated())
                .andExpect(jsonPath("$.user.lastName").value("Бат"))
                .andExpect(jsonPath("$.user.firstName").value("Болд"));
    }

    @Test
    void aCheckRegistersOnlyOnce() throws Exception {
        String phone = "71000002";
        String id = start(phone);
        script.byPhone.put(phone, PhoneVerificationStatus.VERIFIED);
        register(phone, id).andExpect(status().isCreated());

        jdbc.update("DELETE FROM users WHERE phone_number = ?", phone);

        register(phone, id).andExpect(status().isBadRequest());
    }

    @Test
    void aCheckCannotRegisterAnotherPhone() throws Exception {
        String phone = "71000003";
        String id = start(phone);
        script.byPhone.put(phone, PhoneVerificationStatus.VERIFIED);

        register("71000004", id).andExpect(status().isBadRequest());
    }

    @Test
    void anExpiredCheckCannotRegister() throws Exception {
        String phone = "71000005";
        String id = start(phone);
        script.byPhone.put(phone, PhoneVerificationStatus.EXPIRED);

        check(id).andExpect(jsonPath("$.status").value("EXPIRED"));
        register(phone, id).andExpect(status().isBadRequest());
    }

    @Test
    void aRegisteredPhoneCannotStartAnotherCheck() throws Exception {
        String phone = "71000006";
        String id = start(phone);
        script.byPhone.put(phone, PhoneVerificationStatus.VERIFIED);
        register(phone, id).andExpect(status().isCreated());

        json("/auth/phone-verifications", "{\"phoneNumber\":\"%s\"}".formatted(phone))
                .andExpect(status().isConflict());
    }

    @Test
    void startingAgainStraightAwayIsRateLimited() throws Exception {
        String phone = "71000007";
        start(phone);

        json("/auth/phone-verifications", "{\"phoneNumber\":\"%s\"}".formatted(phone))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    void anUnknownCheckIs404() throws Exception {
        check(UUID.randomUUID().toString()).andExpect(status().isNotFound());
    }

    @Test
    void registeringWithoutACheckIsRefused() throws Exception {
        json("/auth/register/viewer", """
                {"phoneNumber":"71000008","password":"password1","lastName":"Бат","firstName":"Болд","gender":"FEMALE","birthDate":"2000-01-01",
                 "city":"Улаанбаатар"}""").andExpect(status().isBadRequest());
    }
}
