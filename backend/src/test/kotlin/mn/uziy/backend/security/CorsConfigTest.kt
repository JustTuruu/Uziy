package mn.uziy.backend.security

import mn.uziy.backend.config.AppProperties
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockHttpServletRequest
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Guardrail against the CORS-bean-name bug we hit on 2026-09-28.
 *
 * Spring Security's `.cors {}` DSL looks up a bean called
 * `corsConfigurationSource` by name. If someone accidentally renames the
 * bean (or the class method) to anything else, no headers get emitted
 * for preflight requests and every browser call from admin_panel dies
 * with a CORS error — which is very hard to spot from a green build.
 *
 * These tests instantiate the config directly and assert the CORS map
 * is populated with the expected origins/methods/headers.
 */
class CorsConfigTest {

    private val props = AppProperties(
        cors = AppProperties.Cors(
            allowedOrigins = listOf(
                "http://localhost:3000",
                "http://localhost:3001",
                "http://localhost:8080",
            ),
        ),
    )

    // We only need the two fields SecurityConfig reads — construct with dummies.
    private val config = SecurityConfig(
        jwtFilter = JwtAuthFilter(JwtService(props.copy(
            jwt = AppProperties.Jwt(secret = "x".repeat(64), ttlHours = 1),
        ))),
        props = props,
    )

    @Test
    fun `CORS bean returns a config for the root path`() {
        val source = config.corsConfigurationSource()
        val req = MockHttpServletRequest("GET", "/auth/login").apply {
            addHeader("Origin", "http://localhost:3000")
        }
        val cfg = source.getCorsConfiguration(req)
        assertNotNull(cfg, "CORS config must be registered on /**")
    }

    @Test
    fun `allowed origins include both consoles (3000, 3001) and 8080`() {
        val cfg = config.corsConfigurationSource()
            .getCorsConfiguration(MockHttpServletRequest("GET", "/x").apply {
                addHeader("Origin", "http://localhost:3000")
            })!!
        assertTrue("http://localhost:3000" in cfg.allowedOrigins!!)
        assertTrue("http://localhost:3001" in cfg.allowedOrigins!!)
        assertTrue("http://localhost:8080" in cfg.allowedOrigins!!)
    }

    @Test
    fun `allowed methods include POST PATCH and OPTIONS`() {
        val cfg = config.corsConfigurationSource()
            .getCorsConfiguration(MockHttpServletRequest("GET", "/x"))!!
        assertTrue("POST"    in cfg.allowedMethods!!)
        assertTrue("PATCH"   in cfg.allowedMethods!!)
        assertTrue("OPTIONS" in cfg.allowedMethods!!)
    }

    @Test
    fun `credentials are allowed`() {
        val cfg = config.corsConfigurationSource()
            .getCorsConfiguration(MockHttpServletRequest("GET", "/x"))!!
        assertEquals(true, cfg.allowCredentials)
    }

    @Test
    fun `bean method is named 'corsConfigurationSource' — Spring auto-lookup depends on it`() {
        // Reflection guard: the DSL bean-by-name resolution won't find a
        // method with any other name. Break this and every browser call 404s
        // with a CORS error but backend logs stay quiet.
        val method = SecurityConfig::class.java.methods
            .firstOrNull { it.name == "corsConfigurationSource" }
        assertNotNull(method,
            "SecurityConfig must expose a bean method called " +
            "'corsConfigurationSource' — see the KDoc on that method.")
    }
}
