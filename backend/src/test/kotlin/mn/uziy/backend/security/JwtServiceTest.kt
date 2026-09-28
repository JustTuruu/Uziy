package mn.uziy.backend.security

import io.jsonwebtoken.security.SignatureException
import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.Role
import mn.uziy.backend.domain.UserEntity
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class JwtServiceTest {

    private fun svc(secret: String = "a".repeat(64)) =
        JwtService(AppProperties(jwt = AppProperties.Jwt(secret = secret, ttlHours = 1)))

    private fun user(id: Long, role: Role) = UserEntity(
        id = id, phoneNumber = "1", passwordHash = "x", role = role,
    )

    @Test
    fun `issue then parse round-trips id and role`() {
        val svc = svc()
        val token = svc.issue(user(42, Role.VIEWER))
        val p = svc.parse(token)
        assertEquals(42, p.userId)
        assertEquals(Role.VIEWER, p.role)
    }

    @Test
    fun `parse fails on a token signed with a different secret`() {
        val issuer = svc(secret = "a".repeat(64))
        val token = issuer.issue(user(1, Role.ADMIN))
        val tamperedVerifier = svc(secret = "b".repeat(64))
        assertFailsWith<SignatureException> {
            tamperedVerifier.parse(token)
        }
    }

    @Test
    fun `parse extracts admin role`() {
        val svc = svc()
        val token = svc.issue(user(7, Role.ADMIN))
        assertEquals(Role.ADMIN, svc.parse(token).role)
    }

    @Test
    fun `parse extracts company role`() {
        val svc = svc()
        val token = svc.issue(user(9, Role.COMPANY))
        assertEquals(Role.COMPANY, svc.parse(token).role)
    }
}
