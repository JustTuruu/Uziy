package mn.zoos.backend.auth

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import mn.zoos.backend.config.AppProperties
import mn.zoos.backend.domain.Gender
import mn.zoos.backend.domain.Role
import mn.zoos.backend.domain.UserEntity
import mn.zoos.backend.domain.UserRepository
import mn.zoos.backend.security.JwtService
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDate
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class AuthControllerTest {

    private val users = mockk<UserRepository>()
    private val encoder = mockk<PasswordEncoder>()
    private val jwt = JwtService(AppProperties(jwt = AppProperties.Jwt("a".repeat(64), 1)))
    private val controller = AuthController(users, encoder, jwt)

    private fun seedUser(role: Role = Role.VIEWER) = UserEntity(
        id = 1L,
        phoneNumber = "88112233",
        passwordHash = "hashed",
        role = role,
        gender = Gender.MALE,
        birthDate = LocalDate.of(2000, 1, 1),
        city = "Улаанбаатар",
        balance = 0.0,
    )

    // ------- login ----------------------------------------------------------

    @Test
    fun `login returns token + Me on correct credentials`() {
        val u = seedUser()
        every { users.findByPhoneNumber("88112233") } returns u
        every { encoder.matches("password", "hashed") } returns true

        val res = controller.login(LoginReq("88112233", "password"))

        assertTrue(res.token.isNotBlank())
        assertEquals(1L, res.user.id)
        assertEquals(Role.VIEWER, res.user.role)
    }

    @Test
    fun `login throws 401 on unknown phone`() {
        every { users.findByPhoneNumber(any()) } returns null
        val ex = assertFailsWith<ResponseStatusException> {
            controller.login(LoginReq("99999999", "password"))
        }
        assertEquals(HttpStatus.UNAUTHORIZED, ex.statusCode)
    }

    @Test
    fun `login throws 401 on bad password`() {
        every { users.findByPhoneNumber("88112233") } returns seedUser()
        every { encoder.matches("wrong", "hashed") } returns false
        val ex = assertFailsWith<ResponseStatusException> {
            controller.login(LoginReq("88112233", "wrong"))
        }
        assertEquals(HttpStatus.UNAUTHORIZED, ex.statusCode)
    }

    // ------- register viewer -----------------------------------------------

    @Test
    fun `registerViewer creates user and returns 201`() {
        every { users.existsByPhoneNumber("77000001") } returns false
        every { encoder.encode("password1") } returns "bcrypt-hash"
        every { users.save(any()) } answers {
            (firstArg<UserEntity>()).also { it.id = 100L }
        }

        val res = controller.registerViewer(RegisterViewerReq(
            phoneNumber = "77000001",
            password = "password1",
            gender = Gender.MALE,
            birthDate = LocalDate.of(2000, 5, 5),
            city = "Улаанбаатар",
        ))

        assertEquals(HttpStatus.CREATED, res.statusCode)
        val me = res.body!!.user
        assertEquals(100L, me.id)
        assertEquals(Role.VIEWER, me.role)
        assertEquals("Улаанбаатар", me.city)
        verify { users.save(match { it.role == Role.VIEWER && it.passwordHash == "bcrypt-hash" }) }
    }

    @Test
    fun `registerViewer throws 409 when phone already exists`() {
        every { users.existsByPhoneNumber("77000001") } returns true
        val ex = assertFailsWith<ResponseStatusException> {
            controller.registerViewer(RegisterViewerReq(
                phoneNumber = "77000001", password = "password1",
                gender = Gender.MALE, birthDate = LocalDate.of(2000, 1, 1),
                city = "Улаанбаатар",
            ))
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
    }

    // ------- register company ----------------------------------------------

    @Test
    fun `registerCompany creates COMPANY role and returns 201`() {
        every { users.existsByPhoneNumber("88112233") } returns false
        every { encoder.encode("password1") } returns "hash"
        every { users.save(any()) } answers {
            (firstArg<UserEntity>()).also { it.id = 42L }
        }

        val res = controller.registerCompany(RegisterCompanyReq(
            phoneNumber = "88112233", password = "password1", companyName = "MobiCom",
        ))

        assertEquals(HttpStatus.CREATED, res.statusCode)
        assertEquals(Role.COMPANY, res.body!!.user.role)
        assertEquals("MobiCom", res.body!!.user.companyName)
    }

    @Test
    fun `registerCompany throws 409 when phone already exists`() {
        every { users.existsByPhoneNumber(any()) } returns true
        val ex = assertFailsWith<ResponseStatusException> {
            controller.registerCompany(RegisterCompanyReq("88112233", "password1", "X"))
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
    }
}
