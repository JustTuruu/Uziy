package mn.uziy.backend.admin

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
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
    private val history = mockk<ViewHistoryRepository>()
    private val payouts = mockk<PayoutRepository>()
    private val platformSettings = mockk<PlatformSettingsRepository>()
    private val controller =
        AdminController(users, campaigns, history, payouts, platformSettings)

    private val adminPrincipal = JwtPrincipal(userId = 1L, role = Role.ADMIN)

    // ------- stats ---------------------------------------------------------

    @Test
    fun `stats aggregates counts and the commission from platform settings`() {
        every { platformSettings.findById(1) } returns Optional.of(
            PlatformSettingsEntity(id = 1, commissionPercent = 35, minRewardPerViewer = 100),
        )
        every { users.count() } returns 24_580
        every { campaigns.count() } returns 147
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.ACTIVE) } returns
                (1..38).map { mockCampaign(it.toLong(), CampaignStatus.ACTIVE) }
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING) } returns
                (1..5).map { mockCampaign(it.toLong(), CampaignStatus.PENDING) }
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.AWAITING_PAYMENT) } returns
                (1..2).map { mockCampaign(it.toLong(), CampaignStatus.AWAITING_PAYMENT) }
        every { payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING) } returns
                (1..3).map { mockPayout(it.toLong()) }

        val s = controller.stats()

        assertEquals(24_580, s.totalUsers)
        assertEquals(147, s.totalCampaigns)
        assertEquals(38, s.activeCampaigns)
        assertEquals(5, s.pendingCampaigns)
        assertEquals(2, s.awaitingPaymentCampaigns)
        assertEquals(3, s.pendingPayouts)
        assertEquals(0.35, s.commissionRate)
        assertEquals(35, s.commissionPercent)
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
        val list = controller.listCampaigns(status = null, companyId = null)
        assertEquals(2, list.size)
    }

    @Test
    fun `listCampaigns with status filters by status`() {
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING) } returns
                listOf(mockCampaign(1, CampaignStatus.PENDING))
        val list = controller.listCampaigns(
            status = CampaignStatus.PENDING, companyId = null,
        )
        assertEquals(1, list.size)
        assertEquals(CampaignStatus.PENDING, list[0].status)
    }

    @Test
    fun `listCampaigns with companyId returns only that company's campaigns`() {
        every { campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L) } returns listOf(
            mockCampaign(1, CampaignStatus.ACTIVE),
            mockCampaign(2, CampaignStatus.PAUSED),
        )
        val list = controller.listCampaigns(status = null, companyId = 500L)
        assertEquals(2, list.size)
    }

    @Test
    fun `listCampaigns with companyId + status filters both`() {
        every { campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L) } returns listOf(
            mockCampaign(1, CampaignStatus.ACTIVE),
            mockCampaign(2, CampaignStatus.PAUSED),
            mockCampaign(3, CampaignStatus.ACTIVE),
        )
        val list = controller.listCampaigns(
            status = CampaignStatus.ACTIVE, companyId = 500L,
        )
        assertEquals(2, list.size)
        assertTrue(list.all { it.status == CampaignStatus.ACTIVE })
    }

    // ------- getCampaign ---------------------------------------------------

    @Test
    fun `getCampaign returns detail with completion count and company name`() {
        val c = mockCampaign(9, CampaignStatus.ACTIVE)
        every { campaigns.findById(9L) } returns Optional.of(c)
        every { users.findById(500L) } returns Optional.of(mockCompany(500L, "MobiCom"))
        every { history.countByCampaignId(9L) } returns 42L

        val d = controller.getCampaign(9L)

        assertEquals(9L, d.campaign.id)
        assertEquals(500L, d.companyId)
        assertEquals("MobiCom", d.companyName)
        assertEquals(42L, d.completedViews)
        assertEquals(100_000.0, d.spentBudget) // 1,000,000 total − 900,000 remaining
    }

    @Test
    fun `getCampaign 404s when the campaign does not exist`() {
        every { campaigns.findById(any()) } returns Optional.empty()
        val ex = assertFailsWith<ResponseStatusException> {
            controller.getCampaign(999L)
        }
        assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
    }

    @Test
    fun `getCampaign tolerates a missing owning company (companyName=null)`() {
        val c = mockCampaign(10, CampaignStatus.ACTIVE)
        every { campaigns.findById(10L) } returns Optional.of(c)
        every { users.findById(500L) } returns Optional.empty()
        every { history.countByCampaignId(10L) } returns 0L

        val d = controller.getCampaign(10L)
        assertEquals(null, d.companyName)
    }

    // ------- getUser -------------------------------------------------------

    @Test
    fun `getUser returns the user`() {
        every { users.findById(500L) } returns Optional.of(
            mockCompany(500L, "MobiCom"),
        )
        val u = controller.getUser(500L)
        assertEquals(500L, u.id)
        assertEquals(Role.COMPANY, u.role)
        assertEquals("MobiCom", u.companyName)
    }

    @Test
    fun `getUser 404s when missing`() {
        every { users.findById(any()) } returns Optional.empty()
        val ex = assertFailsWith<ResponseStatusException> {
            controller.getUser(999L)
        }
        assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
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
    fun `moderate 409s for an unpaid AWAITING_PAYMENT campaign`() {
        every { campaigns.findById(1L) } returns Optional.of(
            mockCampaign(1, CampaignStatus.AWAITING_PAYMENT),
        )
        val ex = assertFailsWith<ResponseStatusException> {
            controller.moderate(1L, CampaignStatus.ACTIVE, adminPrincipal)
        }
        assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        assertEquals(AdminController.UNPAID_MESSAGE, ex.reason)
        verify(exactly = 0) { campaigns.save(any()) }
    }

    @Test
    fun `moderate 404s when the campaign does not exist`() {
        every { campaigns.findById(any()) } returns Optional.empty()
        val ex = assertFailsWith<ResponseStatusException> {
            controller.moderate(1L, CampaignStatus.ACTIVE, adminPrincipal)
        }
        assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
    }

    @Test
    fun `campaign DTOs expose commission snapshot and paidAt`() {
        val paidAt = java.time.OffsetDateTime.now()
        val c = mockCampaign(9, CampaignStatus.PENDING).apply {
            commissionPercent = 30; targetViewers = 1000; this.paidAt = paidAt
        }
        every { campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING) } returns listOf(c)
        val dto = controller.listCampaigns(status = CampaignStatus.PENDING, companyId = null).single()
        assertEquals(30, dto.commissionPercent)
        assertEquals(1000, dto.targetViewers)
        assertEquals(paidAt, dto.paidAt)
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

    private fun mockCompany(id: Long, name: String) = UserEntity(
        id = id, phoneNumber = "88112233", passwordHash = "x",
        role = Role.COMPANY, companyName = name, isVerified = true,
    )
}
