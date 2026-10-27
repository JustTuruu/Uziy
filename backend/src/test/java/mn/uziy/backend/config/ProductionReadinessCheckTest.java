package mn.uziy.backend.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;

class ProductionReadinessCheckTest {

    private static final String REAL_SECRET = "z".repeat(64);

    private final UserRepository users = mock(UserRepository.class);

    private ProductionReadinessCheck check(String secret, boolean simulated, List<String> origins) {
        return check(secret, simulated, "verifymn", origins);
    }

    private ProductionReadinessCheck check(String secret, boolean simulated, String phoneVerification,
                                           List<String> origins) {
        var props = new AppProperties(new AppProperties.Jwt(secret, 24), new AppProperties.Cors(origins),
                new AppProperties.Payments(simulated), new AppProperties.Push(false, ""), new AppProperties.ConsoleLogin(false));
        return new ProductionReadinessCheck(props, users, phoneVerification);
    }

    private ProductionReadinessCheck ready() {
        return check(REAL_SECRET, false, List.of("https://console.uziy.mn"));
    }

    @Test
    void aProperlyConfiguredCleanSystemHasNoProblems() {
        assertThat(ready().problems()).isEmpty();
        assertThatCode(() -> ready().run(new DefaultApplicationArguments())).doesNotThrowAnyException();
    }

    @Test
    void theDevelopmentJwtSecretIsRefused() {
        var secret = "dev-only-secret-change-me-please-do-not-ship-this-keyminimum-256-bit";

        assertThat(check(secret, false, List.of("https://x.mn")).problems()).anyMatch(p -> p.contains("JWT_SECRET"));
    }

    @Test
    void aShortJwtSecretIsRefused() {
        assertThat(check("short", false, List.of("https://x.mn")).problems())
                .anyMatch(p -> p.contains("shorter"));
    }

    @Test
    void simulatedPaymentsAreRefused() {
        assertThat(check(REAL_SECRET, true, List.of("https://x.mn")).problems())
                .anyMatch(p -> p.contains("PAYMENTS_SIMULATED"));
    }

    @Test
    void simulatedPhoneVerificationIsRefused() {
        assertThat(check(REAL_SECRET, false, "simulated", List.of("https://x.mn")).problems())
                .anyMatch(p -> p.contains("PHONE_VERIFICATION_PROVIDER"));
    }

    @Test
    void aLocalCorsOriginIsRefused() {
        assertThat(check(REAL_SECRET, false, List.of("http://localhost:3000")).problems())
                .anyMatch(p -> p.contains("CORS"));
        assertThat(check(REAL_SECRET, false, List.of("http://127.0.0.1:3001")).problems())
                .anyMatch(p -> p.contains("CORS"));
    }

    @Test
    void aSeededDevAccountIsRefused() {
        when(users.existsByPhoneNumber("99990000")).thenReturn(true);

        assertThat(ready().problems()).anyMatch(p -> p.contains("99990000"));
    }

    @Test
    void startupFailsAndNamesEveryProblem() {
        var bad = check("short", true, "simulated", List.of("http://localhost:3000"));

        assertThatThrownBy(() -> bad.run(new DefaultApplicationArguments()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("JWT_SECRET").hasMessageContaining("PAYMENTS_SIMULATED")
                .hasMessageContaining("PHONE_VERIFICATION_PROVIDER")
                .hasMessageContaining("CORS");
    }
}
