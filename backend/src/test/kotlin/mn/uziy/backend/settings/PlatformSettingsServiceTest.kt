package mn.uziy.backend.settings

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.uziy.backend.domain.PlatformSettingsEntity
import mn.uziy.backend.domain.PlatformSettingsRepository
import mn.uziy.backend.domain.Role
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull

class PlatformSettingsControllerTest {

    private val repo = mockk<PlatformSettingsRepository>()
    private val controller = PlatformSettingsController(repo)
    private val admin = JwtPrincipal(userId = 1L, role = Role.ADMIN)

    private fun seed(commission: Int = 30, minReward: Int = 100) =
        PlatformSettingsEntity(id = 1, commissionPercent = commission, minRewardPerViewer = minReward)

    private fun stubSave(): io.mockk.CapturingSlot<PlatformSettingsEntity> {
        val saved = slot<PlatformSettingsEntity>()
        every { repo.save(capture(saved)) } answers { saved.captured }
        return saved
    }

    // ---- GET --------------------------------------------------------------

    @Test
    fun `get returns commission percent and minimum reward`() {
        every { repo.findById(1) } returns Optional.of(seed(30, 100))
        val dto = controller.get()
        assertEquals(30, dto.commissionPercent)
        assertEquals(100, dto.minRewardPerViewer)
        assertNotNull(dto.updatedAt)
    }

    @Test
    fun `get throws when the singleton row is missing (migration failure)`() {
        every { repo.findById(1) } returns Optional.empty()
        assertFailsWith<IllegalStateException> { controller.get() }
    }

    // ---- PATCH ------------------------------------------------------------

    @Test
    fun `update persists new commission + minimum, stamps updatedBy`() {
        every { repo.findById(1) } returns Optional.of(seed())
        val saved = stubSave()

        val dto = controller.update(UpdatePlatformSettingsReq(commissionPercent = 35, minRewardPerViewer = 250), admin)

        assertEquals(35, dto.commissionPercent)
        assertEquals(250, dto.minRewardPerViewer)
        assertEquals(35, saved.captured.commissionPercent)
        assertEquals(250, saved.captured.minRewardPerViewer)
        assertEquals(1L, saved.captured.updatedBy)
    }

    @ParameterizedTest
    @ValueSource(ints = [1, 90])
    fun `commission bounds 1 and 90 are accepted`(commission: Int) {
        every { repo.findById(1) } returns Optional.of(seed())
        stubSave()
        assertEquals(commission,
            controller.update(UpdatePlatformSettingsReq(commission, 1), admin).commissionPercent)
    }

    @ParameterizedTest
    @ValueSource(ints = [0, -5, 91, 100])
    fun `commission outside 1-90 is 400`(commission: Int) {
        every { repo.findById(1) } returns Optional.of(seed())
        val ex = assertFailsWith<ResponseStatusException> {
            controller.update(UpdatePlatformSettingsReq(commission, 100), admin)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
        assertEquals(PlatformSettingsController.COMMISSION_RANGE_MESSAGE, ex.reason)
        verify(exactly = 0) { repo.save(any()) }
    }

    @ParameterizedTest
    @ValueSource(ints = [0, -1])
    fun `minimum reward below 1 is 400`(minReward: Int) {
        every { repo.findById(1) } returns Optional.of(seed())
        val ex = assertFailsWith<ResponseStatusException> {
            controller.update(UpdatePlatformSettingsReq(30, minReward), admin)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
        assertEquals(PlatformSettingsController.MIN_REWARD_MESSAGE, ex.reason)
        verify(exactly = 0) { repo.save(any()) }
    }

    @Test
    fun `missing fields are 400`() {
        every { repo.findById(1) } returns Optional.of(seed())
        val a = assertFailsWith<ResponseStatusException> {
            controller.update(UpdatePlatformSettingsReq(commissionPercent = null, minRewardPerViewer = 100), admin)
        }
        assertEquals(HttpStatus.BAD_REQUEST, a.statusCode)
        val b = assertFailsWith<ResponseStatusException> {
            controller.update(UpdatePlatformSettingsReq(commissionPercent = 30, minRewardPerViewer = null), admin)
        }
        assertEquals(HttpStatus.BAD_REQUEST, b.statusCode)
    }
}
