package mn.uziy.backend.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import mn.uziy.backend.config.AppProperties;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.cors.CorsConfiguration;

/**
 * Guardrail against the CORS-bean-name bug we hit on 2026-09-28.
 *
 * <p>Spring Security's {@code .cors()} DSL looks up a bean called
 * {@code corsConfigurationSource} by name. If someone accidentally renames the
 * bean (or the class method) to anything else, no headers get emitted
 * for preflight requests and every browser call from admin_panel dies
 * with a CORS error — which is very hard to spot from a green build.
 *
 * <p>These tests instantiate the config directly and assert the CORS map
 * is populated with the expected origins/methods/headers.
 */
class CorsConfigTest {

    private final AppProperties props = new AppProperties(
            new AppProperties.Jwt("x".repeat(64), 1),
            new AppProperties.Cors(List.of(
                    "http://localhost:3000",
                    "http://localhost:3001",
                    "http://localhost:8080")),
            new AppProperties.Payments(false),
            new AppProperties.Push(false, ""));

    private final SecurityConfig config = new SecurityConfig(
            new JwtAuthFilter(new JwtService(props)), props);

    private CorsConfiguration cfgFor(MockHttpServletRequest req) {
        return config.corsConfigurationSource().getCorsConfiguration(req);
    }

    @Test
    void corsBeanReturnsAConfigForTheRootPath() {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/auth/login");
        req.addHeader("Origin", "http://localhost:3000");
        assertThat(cfgFor(req)).as("CORS config must be registered on /**").isNotNull();
    }

    @Test
    void allowedOriginsIncludeBothConsolesAnd8080() {
        MockHttpServletRequest req = new MockHttpServletRequest("GET", "/x");
        req.addHeader("Origin", "http://localhost:3000");
        CorsConfiguration cfg = cfgFor(req);
        assertThat(cfg.getAllowedOrigins()).contains(
                "http://localhost:3000", "http://localhost:3001", "http://localhost:8080");
    }

    @Test
    void allowedMethodsIncludePostPatchAndOptions() {
        CorsConfiguration cfg = cfgFor(new MockHttpServletRequest("GET", "/x"));
        assertThat(cfg.getAllowedMethods()).contains("POST", "PATCH", "OPTIONS");
    }

    @Test
    void credentialsAreAllowed() {
        CorsConfiguration cfg = cfgFor(new MockHttpServletRequest("GET", "/x"));
        assertThat(cfg.getAllowCredentials()).isEqualTo(true);
    }

    @Test
    void beanMethodIsNamedCorsConfigurationSourceSpringAutoLookupDependsOnIt() {
        // Reflection guard: the DSL bean-by-name resolution won't find a
        // method with any other name.
        assertThat(Arrays.stream(SecurityConfig.class.getMethods())
                .anyMatch(m -> m.getName().equals("corsConfigurationSource")))
                .as("SecurityConfig must expose a bean method called 'corsConfigurationSource'")
                .isTrue();
    }
}
