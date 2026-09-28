package mn.uziy.backend.admin

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Test
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import java.time.LocalDate
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class AdminControllerTest {

    private val users = mockk<UserRepository>()
    private val campaigns = mockk<CampaignRepository>()
    private val payouts = mockk<PayoutRepository>()
    private val props = AppProperties(reward = AppProperties.Reward(commissionRate = 0.35))
    private val controller = AdminController(users, campaigns, payouts, props)

    private val adminPrincipal = JwtPrincipal(userId = 1L, role = Role.ADMIN)

    // ------- stats ---------------------------------------------------------

    @Test
    fun `stats aggregates counts and commission rate from properties`() {
        every { users.count() } returns 24_580
        every { campaigns.count() } returns 147
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.ACTIVE) } returns
                (1..38).map { mockCampaign(it.toLong(), CampaignStatus.ACTIVE) }
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING) } returns
                (1..5).map { mockCampaign(it.toLong(), CampaignStatus.PENDING) }
        every { payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING) } returns
                (1..3).map { mockPayout(it.toLong()) }

        val s = controller.stats()

        assertEquals(24_580, s.totalUsers)
        assertEquals(147, s.totalCampaigns)
        assertEquals(38, s.activeCampaigns)
        assertEquals(5, s.pendingCampaigns)
        assertEquals(3, s.pendingPayouts)
        assertEquals(0.35, s.commissionRate)
    }

    // ------- listUsers -----------------------------------------------------

    @Test
    fun `listUsers maps all users to UserDto`() {
        every { users.findAll() } returns listOf(
            UserEntity(id = 10L, phoneNumber = "88112233", passwordHash = "x",
                role = Role.VIEWER, gender = Gender.MALE,
                birthDate = LocalDate.now().minusYears(30),
                city = "Улаанбаатар", balance = 5000.0, isVerified = true),
        )
        val list = controller.listUsers()
        assertEquals(1, list.size)
        assertEquals(30, list[0].age)
        assertTrue(list[0].isVerified)
    }

    // ------- verify --------------------------------------------------------

    @Test
    fun `verify sets is_verified to TRUE`() {
        val u = UserEntity(id = 10L, phoneNumber = "1", passwordHash = "x",
            role = Role.VIEWER, isVerified = false)
        every { users.findById(10L) } returns Optional.of(u)
        val saved = slot<UserEntity>()
        every { users.save(capture(saved)) } answers { saved.captured }

        val dto = controller.verify(10L)

        assertTrue(dto.isVerified)
        assertTrue(saved.captured.isVerified)
    }

    // ------- listCampaigns -------------------------------------------------

    @Test
    fun `listCampaigns without status returns all`() {
        every { campaigns.findAll() } returns listOf(
            mockCampaign(1, CampaignStatus.ACTIVE),
            mockCampaign(2, CampaignStatus.PAUSED),
        )
        val list = controller.listCampaigns(status = null)
        assertEquals(2, list.size)
    }

    @Test
    fun `listCampaigns with status filters by status`() {
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING) } returns
                listOf(mockCampaign(1, CampaignStatus.PENDING))
        val list = controller.listCampaigns(status = CampaignStatus.PENDING)
        assertEquals(1, list.size)
        assertEquals(CampaignStatus.PENDING, list[0].status)
    }

    // ------- moderate ------------------------------------------------------

    @Test
    fun `moderate ACTIVE approves a PENDING campaign`() {
        val c = mockCampaign(1, CampaignStatus.PENDING)
        every { campaigns.findById(1L) } returns Optional.of(c)
        val saved = slot<CampaignEntity>()
        every { campaigns.save(capture(saved)) } answers { saved.captured }

        val dto = controller.moderate(1L, CampaignStatus.ACTIVE, adminPrincipal)
        assertEquals(CampaignStatus.ACTIVE, dto.status)
        assertEquals(CampaignStatus.ACTIVE, saved.captured.status)
    }

    @Test
    fun `moderate REJECTED rejects a PENDING campaign`() {
        val c = mockCampaign(1, CampaignStatus.PENDING)
        every { campaigns.findById(1L) } returns Optional.of(c)
        every { campaigns.save(any()) } answers { firstArg() }

        val dto = controller.moderate(1L, CampaignStatus.REJECTED, adminPrincipal)
        assertEquals(CampaignStatus.REJECTED, dto.status)
    }

    @Test
    fun `moderate rejects invalid decisions like PAUSED`() {
        val ex = assertFailsWith<ResponseStatusException> {
            controller.moderate(1L, CampaignStatus.PAUSED, adminPrincipal)
        }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
    }

    @Test
    fun `moderate 409s when campaign is not PENDING`() {
        every { campaigns.findById(1L) } returns Optional.of(
            mockCampaign(1, CampaignStatus.ACTIVE),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.moderate(1L, CampaignStatus.ACTIVE, adminPrincipal)
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
    }

    // ---- helpers ----------------------------------------------------------

    private fun mockCampaign(id: Long, status: CampaignStatus) = CampaignEntity(
        id = id, companyId = 500L, title = "T", durationSeconds = 30,
        targetGender = TargetGender.ALL, minAge = 18, maxAge = 45,
        targetCity = "Улаанбаатар", totalBudget = 1_000_000.0,
        remainingBudget = 900_000.0, costPerView = 1000.0,
        rewardPerUser = 700.0, status = status,
    )

    private fun mockPayout(id: Long) = PayoutEntity(
        id = id, userId = 42L, amount = 500.0, bank = "Khan",
        accountNumber = "1", accountName = "X", nationalId = "Y",
        status = PayoutStatus.PENDING,
    )
}
