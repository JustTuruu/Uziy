package mn.uziy.backend.settings

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import mn.uziy.backend.domain.PlatformSettingsEntity
import mn.uziy.backend.domain.PlatformSettingsRepository
import mn.uziy.backend.domain.Role
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class PlatformSettingsControllerTest {

    private val repo = mockk<PlatformSettingsRepository>()
    private val controller = PlatformSettingsController(repo)
    private val admin = JwtPrincipal(userId = 1L, role = Role.ADMIN)

    private fun seed(cost: Double = 400.0, reward: Double = 250.0) =
        PlatformSettingsEntity(
            id = 1,
            surveyOnlyCostPerResponse = cost,
            surveyOnlyRewardPerUser = reward,
        )

    // ---- GET --------------------------------------------------------------

    @Test
    fun `get returns the singleton row as a DTO`() {
        every { repo.findById(1) } returns Optional.of(seed(400.0, 250.0))
        val dto = controller.get()
        assertEquals(400.0, dto.surveyOnlyCostPerResponse)
        assertEquals(250.0, dto.surveyOnlyRewardPerUser)
    }

    @Test
    fun `get throws when the singleton row is missing (migration failure)`() {
        every { repo.findById(1) } returns Optional.empty()
        assertFailsWith<IllegalStateException> { controller.get() }
    }

    // ---- PATCH ------------------------------------------------------------

    @Test
    fun `update persists new prices, stamps updatedAt + updatedBy`() {
        every { repo.findById(1) } returns Optional.of(seed(400.0, 250.0))
        val saved = slot<PlatformSettingsEntity>()
        every { repo.save(capture(saved)) } answers { saved.captured }

        val dto = controller.update(
            body = UpdatePlatformSettingsReq(
                surveyOnlyCostPerResponse = 600.0,
                surveyOnlyRewardPerUser   = 350.0,
            ),
            admin = admin,
        )

        assertEquals(600.0, dto.surveyOnlyCostPerResponse)
        assertEquals(350.0, dto.surveyOnlyRewardPerUser)
        assertEquals(1L, saved.captured.updatedBy)
    }

    @Test
    fun `update rejects reward greater than or equal to cost`() {
        every { repo.findById(1) } returns Optional.of(seed())
        val ex = assertFailsWith<ResponseStatusException> {
            controller.update(
                UpdatePlatformSettingsReq(
                    surveyOnlyCostPerResponse = 500.0,
                    surveyOnlyRewardPerUser   = 500.0,
                ), admin,
            )
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    @Test
    fun `update rejects reward strictly greater than cost`() {
        every { repo.findById(1) } returns Optional.of(seed())
        val ex = assertFailsWith<ResponseStatusException> {
            controller.update(
                UpdatePlatformSettingsReq(
                    surveyOnlyCostPerResponse = 300.0,
                    surveyOnlyRewardPerUser   = 400.0,
                ), admin,
            )
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }
}
