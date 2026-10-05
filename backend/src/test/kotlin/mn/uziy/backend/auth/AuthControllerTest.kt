package mn.uziy.backend.auth

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import mn.uziy.backend.domain.Role
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import java.time.LocalDate
import kotlin.test.assertEquals
import kotlin.test.assertSame

/** The controller is an adapter: it delegates to [AuthService] and sets the HTTP status. */
class AuthControllerTest {

    private val service = mockk<AuthService>()
    private val controller = AuthController(service)

    private fun response(role: Role) = AuthResponse(
        token = "t",
        user = Me(1L, "88112233", role, null, null, null, 0.0, false, null),
    )

    @Test
    fun `login delegates to the service and returns its response`() {
        val res = response(Role.VIEWER)
        val req = LoginReq("88112233", "password")
        every { service.login(req) } returns res
        assertSame(res, controller.login(req))
    }

    @Test
    fun `registerViewer answers 201 with the service response`() {
        val req = RegisterViewerReq("88112233", "password1", mn.uziy.backend.domain.Gender.MALE,
            LocalDate.of(2000, 1, 1), "Улаанбаатар")
        every { service.registerViewer(req) } returns response(Role.VIEWER)

        val out = controller.registerViewer(req)

        assertEquals(HttpStatus.CREATED, out.statusCode)
        assertEquals(Role.VIEWER, out.body!!.user.role)
    }

    @Test
    fun `registerCompany answers 201 with the service response`() {
        val req = RegisterCompanyReq("88112233", "password1", "MobiCom")
        every { service.registerCompany(req) } returns response(Role.COMPANY)

        val out = controller.registerCompany(req)

        assertEquals(HttpStatus.CREATED, out.statusCode)
        verify(exactly = 1) { service.registerCompany(req) }
    }
}
