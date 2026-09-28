package mn.uziy.backend.integration

import mn.uziy.backend.auth.AuthController
import mn.uziy.backend.auth.LoginReq
import mn.uziy.backend.domain.Role
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * Regression test — proves the V3 seed-password fix actually made the
 * dev-seed users loginable. If someone breaks V3 or the seed passwords
 * drift, this test screams before the frontend team hits it.
 */
@SpringBootTest
@Testcontainers
class SeedLoginIntegrationTest {

    companion object {
        @Container
        @JvmStatic
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("uziy_seed_test")
            .withUsername("test")
            .withPassword("test")

        @JvmStatic
        @DynamicPropertySource
        fun props(registry: DynamicPropertyRegistry) {
            registry.add("spring.datasource.url") { postgres.jdbcUrl }
            registry.add("spring.datasource.username") { postgres.username }
            registry.add("spring.datasource.password") { postgres.password }
        }
    }

    @Autowired lateinit var auth: AuthController

    @Test
    fun `seeded admin (id=1) can log in with password 'password'`() {
        val res = auth.login(LoginReq(phoneNumber = "99990000", password = "password"))
        assertEquals(Role.ADMIN, res.user.role)
        assertTrue(res.token.isNotBlank())
    }

    @Test
    fun `seeded company MobiCom can log in with password 'password'`() {
        val res = auth.login(LoginReq(phoneNumber = "88112233", password = "password"))
        assertEquals(Role.COMPANY, res.user.role)
        assertEquals("MobiCom", res.user.companyName)
    }

    @Test
    fun `seeded viewer id=100 can log in with password 'password'`() {
        val res = auth.login(LoginReq(phoneNumber = "88778899", password = "password"))
        assertEquals(Role.VIEWER, res.user.role)
        assertEquals("Улаанбаатар", res.user.city)
    }
}
