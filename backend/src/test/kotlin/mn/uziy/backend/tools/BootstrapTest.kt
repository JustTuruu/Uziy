package mn.uziy.backend.tools

import mn.uziy.backend.domain.Role
import mn.uziy.backend.domain.UserRepository
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

/**
 * Verifies the bootstrap CLI helpers against a real Postgres:
 * - `bcrypt()` returns a hash that Spring's PasswordEncoder can verify
 *   (proves the seed-hash workflow round-trips)
 * - `makeAdmin()` upserts an ADMIN row and re-running is idempotent
 */
@SpringBootTest
@Testcontainers
class BootstrapTest {

    companion object {
        @Container
        @JvmStatic
        val postgres: PostgreSQLContainer<*> = PostgreSQLContainer("postgres:16-alpine")
            .withDatabaseName("uziy_test")
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

    @Autowired lateinit var users: UserRepository
    @Autowired lateinit var encoder: PasswordEncoder

    @Test
    fun `bcrypt output verifies against Spring's PasswordEncoder`() {
        val hash = bcrypt("hunter2")
        assertTrue(encoder.matches("hunter2", hash),
            "hash produced by bcrypt() must round-trip through PasswordEncoder")
    }

    @Test
    fun `bcrypt rejects empty password`() {
        assertFailsWith<IllegalArgumentException> { bcrypt("") }
    }

    @Test
    fun `makeAdmin inserts a new admin with the correct role and verified flag`() {
        val id = makeAdmin(
            phoneNumber = "77555001",
            password = "hunter2",
            dbUrl = postgres.jdbcUrl,
            dbUser = postgres.username,
            dbPass = postgres.password,
        )
        val u = users.findById(id).orElseThrow()
        assertEquals(Role.ADMIN, u.role)
        assertTrue(u.isVerified)
        assertTrue(encoder.matches("hunter2", u.passwordHash))
    }

    @Test
    fun `makeAdmin re-run on same phone updates role and password`() {
        val id1 = makeAdmin("77555002", "first-password",
            postgres.jdbcUrl, postgres.username, postgres.password)
        val id2 = makeAdmin("77555002", "second-password",
            postgres.jdbcUrl, postgres.username, postgres.password)

        assertEquals(id1, id2, "same phone should upsert to the same row")

        val u = users.findById(id1).orElseThrow()
        assertEquals(Role.ADMIN, u.role)
        assertTrue(encoder.matches("second-password", u.passwordHash),
            "password should be updated on re-run")
        assertTrue(!encoder.matches("first-password", u.passwordHash),
            "old password should no longer verify")
    }

    @Test
    fun `makeAdmin rejects malformed phone`() {
        assertFailsWith<IllegalArgumentException> {
            makeAdmin("bad-phone", "hunter2",
                postgres.jdbcUrl, postgres.username, postgres.password)
        }
    }

    @Test
    fun `makeAdmin rejects short password`() {
        assertFailsWith<IllegalArgumentException> {
            makeAdmin("77555003", "short",
                postgres.jdbcUrl, postgres.username, postgres.password)
        }
    }
}
