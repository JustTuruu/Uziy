package mn.uziy.backend.phoneverify;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import java.time.OffsetDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

/**
 * Pattern: Strategy — verify.mn (Mongolia-only, mobile-originated SMS): the user texts our code from their
 * own phone to the 144773 short code, which proves they hold that number. We poll
 * {@code GET /sessions/{id}} instead of taking callbacks, so no public callback URL is needed.
 * The API key is only ever sent on {@code POST /sessions} and never logged.
 */
@Component
@ConditionalOnProperty(prefix = "uziy.phone-verification", name = "provider", havingValue = "verifymn")
public class VerifyMnGateway implements PhoneVerificationGateway {

    static final String SESSIONS = "/sessions";
    static final String SESSION = "/sessions/{sessionId}";
    /** ASCII only (verify.mn rule); Unitel replaces it with its default reply and Lime sends none. */
    static final String RESPONSE_SMS = "Uziy: Tany dugaar batalgaajlaa.";
    static final String MISSING_KEY =
            "uziy.phone-verification.provider=verifymn but VERIFY_MN_API_KEY is not set";

    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(10);

    private final RestClient http;
    private final String bearer;

    @Autowired
    public VerifyMnGateway(@Value("${uziy.phone-verification.verify-mn.base-url}") String baseUrl,
                           @Value("${uziy.phone-verification.verify-mn.api-key:}") String apiKey) {
        this(RestClient.builder().requestFactory(timeoutRequestFactory()), baseUrl, apiKey);
    }

    /** Takes the builder so tests can bind a mock server to it. */
    VerifyMnGateway(RestClient.Builder builder, String baseUrl, String apiKey) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException(MISSING_KEY);
        }
        this.http = builder.baseUrl(baseUrl).build();
        this.bearer = "Bearer " + apiKey;
    }

    private static JdkClientHttpRequestFactory timeoutRequestFactory() {
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(
                HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build());
        factory.setReadTimeout(READ_TIMEOUT);
        return factory;
    }

    @Override
    public PhoneVerificationSession start(String phoneNumber, String text) {
        SessionBody res = call("create session", () -> http.post()
                .uri(SESSIONS)
                .header(HttpHeaders.AUTHORIZATION, bearer)
                .contentType(MediaType.APPLICATION_JSON)
                .body(new StartBody(phoneNumber, text, RESPONSE_SMS))
                .retrieve()
                .body(SessionBody.class));
        if (res == null || res.sessionId() == null || res.expiresAt() == null) {
            throw new PhoneVerificationGatewayException("verify.mn create session: incomplete answer");
        }
        return new PhoneVerificationSession(res.sessionId(), res.shortcode(), res.text(), res.smsUri(),
                res.displayInstruction(), res.expiresAt());
    }

    @Override
    public PhoneVerificationStatus status(String sessionId) {
        try {
            StatusBody res = call("session status", () -> http.get()
                    .uri(SESSION, sessionId)
                    .retrieve()
                    .body(StatusBody.class));
            if (res == null || res.sessionStatus() == null) {
                throw new PhoneVerificationGatewayException("verify.mn session status: empty answer");
            }
            return PhoneVerificationStatus.valueOf(res.sessionStatus());
        } catch (IllegalArgumentException e) {
            throw new PhoneVerificationGatewayException("verify.mn session status: unknown value", e);
        } catch (PhoneVerificationGatewayException e) {
            if (e.getCause() instanceof HttpClientErrorException.NotFound) {
                return PhoneVerificationStatus.EXPIRED;
            }
            throw e;
        }
    }

    /** Runs one HTTP call; every client failure becomes a gateway exception that names only the HTTP status. */
    private static <T> T call(String what, java.util.function.Supplier<T> request) {
        try {
            return request.get();
        } catch (RestClientResponseException e) {
            throw new PhoneVerificationGatewayException(
                    "verify.mn " + what + " answered " + e.getStatusCode().value(), e);
        } catch (RestClientException e) {
            throw new PhoneVerificationGatewayException("verify.mn " + what + " failed: " + e.getClass().getSimpleName(), e);
        }
    }

    record StartBody(String phone, String text, String responseSms) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record SessionBody(String sessionId, String shortcode, String text, String smsUri,
                       String displayInstruction, OffsetDateTime expiresAt) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record StatusBody(String sessionStatus) {
    }
}
