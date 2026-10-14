package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.jayway.jsonpath.JsonPath;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import mn.uziy.backend.auth.AuthServiceImpl;
import mn.uziy.backend.common.FieldMessages;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

/**
 * What a user actually reads when something goes wrong, through a real HTTP server — Spring Security, the
 * container's error dispatch, SafeErrorAttributes — which MockMvc does not run: always Mongolian, never Spring's
 * English, never an echoed value.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ErrorMessagesIntegrationTest extends AbstractApiIntegrationTest {

    private static final String CYRILLIC = "(?s).*[А-Яа-яӨөҮүЁё].*";

    @LocalServerPort int port;

    private final HttpClient http = HttpClient.newHttpClient();

    private String body(HttpRequest.Builder request) throws Exception {
        HttpResponse<String> res = http.send(request.build(), HttpResponse.BodyHandlers.ofString());
        assertThat(res.statusCode()).isGreaterThanOrEqualTo(400);
        assertThat(res.body()).doesNotContain("\"errors\"");
        return res.body();
    }

    private String message(HttpRequest.Builder request) throws Exception {
        return JsonPath.read(body(request), "$.message");
    }

    private HttpRequest.Builder get(String path) {
        return HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).GET();
    }

    private HttpRequest.Builder postJson(String path, String json) {
        return HttpRequest.newBuilder(URI.create("http://localhost:" + port + path))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json));
    }

    /** Regression (2026-10-13): a wrong password showed "Invalid credentials". */
    @Test
    void aWrongPasswordIsExplainedInMongolian() throws Exception {
        long viewer = viewer(0);
        String phone = jdbc.queryForObject("SELECT phone_number FROM users WHERE id = ?", String.class, viewer);

        assertThat(message(postJson("/auth/login", "{\"phoneNumber\":\"" + phone + "\",\"password\":\"wrong-pass\"}")))
                .isEqualTo(AuthServiceImpl.INVALID_CREDENTIALS);
    }

    /** Regression (2026-10-13): "Validation failed for object='loginReq'. Error count: 1" plus the rejected value. */
    @Test
    void anInvalidFieldNamesTheFieldAndNeverEchoesThePassword() throws Exception {
        String body = body(postJson("/auth/login", "{\"phoneNumber\":\"12\",\"password\":\"my-secret\"}"));

        assertThat((String) JsonPath.read(body, "$.message")).isEqualTo(FieldMessages.PHONE);
        assertThat(body).doesNotContain("my-secret");
    }

    @Test
    void springsOwnErrorsAreReplacedWithMongolian() throws Exception {
        assertThat(message(get("/auth/phone-verifications/not-a-uuid"))).matches(CYRILLIC).doesNotContain("UUID");
        assertThat(message(get("/viewer/me"))).matches(CYRILLIC).doesNotContain("Forbidden");
        assertThat(message(postJson("/auth/login", "{not json"))).matches(CYRILLIC);
        assertThat(message(get("/no-such-route"))).matches(CYRILLIC);
    }
}
