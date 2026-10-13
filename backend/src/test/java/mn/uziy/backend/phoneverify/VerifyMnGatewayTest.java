package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.headerDoesNotExist;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import java.time.OffsetDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.json.JsonCompareMode;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

class VerifyMnGatewayTest {

    private static final String BASE = "https://api.verify.mn";

    private final RestClient.Builder builder = RestClient.builder();
    private final MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
    private final VerifyMnGateway gateway = new VerifyMnGateway(builder, BASE, "test-key");

    @Test
    void startPostsPhoneAndCodeWithTheBearerKeyAndReturnsTheInstructions() {
        server.expect(requestTo(BASE + "/sessions"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header(HttpHeaders.AUTHORIZATION, "Bearer test-key"))
                .andExpect(content().json("""
                        {"phone":"88112233","text":"482916","responseSms":"%s"}"""
                        .formatted(VerifyMnGateway.RESPONSE_SMS), JsonCompareMode.STRICT))
                .andRespond(withSuccess("""
                        {"sessionId":"a1b2","phone":"88112233","shortcode":"144773","text":"482916",
                         "smsUri":"sms:144773?body=482916","displayInstruction":"Та өөрийн 88112233 ...",
                         "expiresAt":"2026-04-14T12:30:00.000Z","somethingNew":1}""", MediaType.APPLICATION_JSON));

        PhoneVerificationSession s = gateway.start("88112233", "482916");

        assertThat(s.sessionId()).isEqualTo("a1b2");
        assertThat(s.shortcode()).isEqualTo("144773");
        assertThat(s.smsUri()).isEqualTo("sms:144773?body=482916");
        assertThat(s.displayInstruction()).isEqualTo("Та өөрийн 88112233 ...");
        assertThat(s.expiresAt().toInstant()).isEqualTo(OffsetDateTime.parse("2026-04-14T12:30:00Z").toInstant());
        server.verify();
    }

    @Test
    void aRejectedApiKeyIsAGatewayFailureThatNamesOnlyTheStatus() {
        server.expect(requestTo(BASE + "/sessions"))
                .andRespond(withStatus(HttpStatus.UNAUTHORIZED).body("{\"message\":\"bad key\"}"));

        assertThatThrownBy(() -> gateway.start("88112233", "482916"))
                .isInstanceOf(PhoneVerificationGatewayException.class)
                .hasMessage("verify.mn create session answered 401");
    }

    @Test
    void aServerErrorOnStartIsAGatewayFailure() {
        server.expect(requestTo(BASE + "/sessions")).andRespond(withServerError());

        assertThatThrownBy(() -> gateway.start("88112233", "482916"))
                .isInstanceOf(PhoneVerificationGatewayException.class);
    }

    @Test
    void statusReadsEachSessionStatusAndSendsNoKey() {
        for (PhoneVerificationStatus expected : PhoneVerificationStatus.values()) {
            server.expect(requestTo(BASE + "/sessions/a1b2"))
                    .andExpect(method(HttpMethod.GET))
                    .andExpect(headerDoesNotExist(HttpHeaders.AUTHORIZATION))
                    .andRespond(withSuccess("""
                            {"sessionId":"a1b2","sessionStatus":"%s","callbackStatus":"PENDING",
                             "verifiedAt":null,"expiresAt":"2026-04-14T12:30:00.000Z"}""".formatted(expected),
                            MediaType.APPLICATION_JSON));

            assertThat(gateway.status("a1b2")).isEqualTo(expected);
            server.verify();
            server.reset();
        }
    }

    @Test
    void aSessionTheProviderNoLongerKnowsIsExpired() {
        server.expect(requestTo(BASE + "/sessions/gone")).andRespond(withStatus(HttpStatus.NOT_FOUND));

        assertThat(gateway.status("gone")).isEqualTo(PhoneVerificationStatus.EXPIRED);
    }

    @Test
    void anUnknownStatusValueIsAGatewayFailure() {
        server.expect(requestTo(BASE + "/sessions/a1b2"))
                .andRespond(withSuccess("{\"sessionStatus\":\"WEIRD\"}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> gateway.status("a1b2")).isInstanceOf(PhoneVerificationGatewayException.class);
    }

    @Test
    void aServerErrorOnStatusIsAGatewayFailure() {
        server.expect(requestTo(BASE + "/sessions/a1b2")).andRespond(withServerError());

        assertThatThrownBy(() -> gateway.status("a1b2")).isInstanceOf(PhoneVerificationGatewayException.class);
    }

    @Test
    void aMissingApiKeyStopsStartup() {
        assertThatThrownBy(() -> new VerifyMnGateway(RestClient.builder(), BASE, " "))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("VERIFY_MN_API_KEY");
    }

    @Test
    void theReplySmsIsPrintableAsciiWithinTheProvidersLimit() {
        assertThat(VerifyMnGateway.RESPONSE_SMS).hasSizeLessThanOrEqualTo(160).matches("[\\x20-\\x7E]+");
    }
}
