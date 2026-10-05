package mn.uziy.backend.company

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.*
import mn.uziy.backend.payment.PaymentReference
import mn.uziy.backend.payment.SimulatedPaymentGateway
import mn.uziy.backend.security.JwtPrincipal
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpStatus
import mn.uziy.backend.support.assertFailsWithHttp
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class CompanyServicesTest {

    private val campaigns = mockk<CampaignRepository>()
    private val questions = mockk<SurveyQuestionRepository>()
    private val platformSettings = mockk<PlatformSettingsRepository>()
    private val payments = mockk<CampaignPaymentRepository>()

    private fun paymentService(simulated: Boolean = true) = CampaignPaymentServiceImpl(
        campaigns, payments,
        listOf(SimulatedPaymentGateway(
            AppProperties(payments = AppProperties.Payments(simulated = simulated)),
        )),
    )

    private val campaignSvc = CampaignServiceImpl(campaigns, questions, platformSettings)
    private val paymentSvc = paymentService()
    private val principal = JwtPrincipal(userId = 500L, role = Role.COMPANY)

    private fun settings(commission: Int = 30, minReward: Int = 100) {
        every { platformSettings.findById(1) } returns Optional.of(
            PlatformSettingsEntity(id = 1, commissionPercent = commission, minRewardPerViewer = minReward),
        )
    }

    init {
        settings()
    }

    private fun sampleCampaign(
        id: Long,
        ownerId: Long = 500L,
        status: CampaignStatus = CampaignStatus.ACTIVE,
    ) = CampaignEntity(
        id = id, companyId = ownerId, title = "T$id",
        durationSeconds = 30, targetGender = TargetGender.ALL,
        minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
        totalBudget = 1_000_000.0, remainingBudget = 900_000.0,
        costPerView = 1000.0, rewardPerUser = 700.0, status = status,
        targetViewers = 1000, commissionPercent = 30,
    )

    private fun videoReq(
        totalBudget: Double? = 1_000_000.0,
        targetViewers: Int? = null,
        rewardPerUser: Double? = null,
        durationSeconds: Int = 45,
    ) = CreateCampaignReq(
        title = "Шинэ 5G",
        durationSeconds = durationSeconds,
        targetGender = TargetGender.ALL,
        minAge = 18, maxAge = 45, targetCity = "Улаанбаатар",
        totalBudget = totalBudget,
        targetViewers = targetViewers,
        rewardPerUser = rewardPerUser,
        questions = listOf(
            CreateCampaignReq.NewQuestion(prompt = "P", type = "SINGLE_CHOICE", options = listOf("A", "B")),
        ),
    )

    /** Stub saves and return the slot holding the persisted campaign. */
    private fun captureSave(id: Long = 77L): io.mockk.CapturingSlot<CampaignEntity> {
        val saved = slot<CampaignEntity>()
        every { campaigns.save(capture(saved)) } answers { saved.captured.also { it.id = id } }
        every { questions.save(any()) } answers { firstArg() }
        return saved
    }

    private fun assertBadRequest(message: String, block: () -> Unit) {
        val ex = assertFailsWithHttp { block() }
        assertEquals(HttpStatus.BAD_REQUEST, ex.statusCode)
        assertEquals(message, ex.reason)
    }

    // ------- list / get ------------------------------------------------------

    @Nested
    inner class Read {

        @Test
        fun `list returns only own campaigns`() {
            every { campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L) } returns
                    listOf(sampleCampaign(1), sampleCampaign(2))
            assertEquals(2, campaignSvc.list(principal.userId).size)
            verify { campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L) }
        }

        @Test
        fun `get returns campaign owned by caller with the new pricing fields`() {
            every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1))
            val dto = campaignSvc.get(principal.userId, 1L)
            assertEquals(1L, dto.id)
            assertEquals(1000, dto.targetViewers)
            assertEquals(30, dto.commissionPercent)
            assertEquals(null, dto.paidAt)
        }

        @Test
        fun `get throws 403 for campaign owned by another company`() {
            every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1, ownerId = 999L))
            val ex = assertFailsWithHttp { campaignSvc.get(principal.userId, 1L) }
            assertEquals(HttpStatus.FORBIDDEN, ex.statusCode)
        }

        @Test
        fun `get throws 404 when campaign not found`() {
            every { campaigns.findById(any()) } returns Optional.empty()
            val ex = assertFailsWithHttp { campaignSvc.get(principal.userId, 999L) }
            assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
        }
    }

    // ------- create ----------------------------------------------------------

    @Nested
    inner class Create {

        @Test
        fun `VIEWERS mode - 1,000,000 for 1,000 viewers saves C=1000 R=700 in AWAITING_PAYMENT`() {
            val saved = captureSave()
            val dto = campaignSvc.create(principal.userId, videoReq(targetViewers = 1_000))

            assertEquals(77L, dto.id)
            val c = saved.captured
            assertEquals(CampaignStatus.AWAITING_PAYMENT, c.status)
            assertEquals(CampaignStatus.AWAITING_PAYMENT, dto.status)
            assertEquals(500L, c.companyId)
            assertEquals(1_000_000.0, c.totalBudget)
            assertEquals(1_000_000.0, c.remainingBudget)
            assertEquals(1000.0, c.costPerView)
            assertEquals(700.0, c.rewardPerUser)
            assertEquals(1000, c.targetViewers)
            assertEquals(30, c.commissionPercent)
            assertEquals(null, c.paidAt)
            assertEquals(1000, dto.targetViewers)
            assertEquals(30, dto.commissionPercent)
            verify(exactly = 1) {
                questions.save(match {
                    it.campaignId == 77L && it.prompt == "P" && it.qType == "SINGLE_CHOICE" &&
                        it.position == 1 && it.optionsJson == "[\"A\", \"B\"]"
                })
            }
        }

        @Test
        fun `VIEWERS mode charges only the payable amount, not the unused remainder`() {
            val saved = captureSave()
            campaignSvc.create(principal.userId, videoReq(targetViewers = 1_428))
            assertEquals(999_600.0, saved.captured.totalBudget)
            assertEquals(999_600.0, saved.captured.remainingBudget)
            assertEquals(700.0, saved.captured.costPerView)
            assertEquals(490.0, saved.captured.rewardPerUser)
            assertEquals(1428, saved.captured.targetViewers)
        }

        @Test
        fun `REWARD mode - 500 per viewer derives C=715 and N=1398`() {
            val saved = captureSave()
            val dto = campaignSvc.create(principal.userId, videoReq(rewardPerUser = 500.0))
            val c = saved.captured
            assertEquals(715.0, c.costPerView)
            assertEquals(500.0, c.rewardPerUser)
            assertEquals(1398, c.targetViewers)
            assertEquals(999_570.0, c.totalBudget)
            assertEquals(999_570.0, c.remainingBudget)
            assertEquals(CampaignStatus.AWAITING_PAYMENT, dto.status)
        }

        @Test
        fun `uses the CURRENT platform commission and snapshots it`() {
            settings(commission = 35)
            val saved = captureSave()
            campaignSvc.create(principal.userId, videoReq(totalBudget = 500_000.0, targetViewers = 1_000))
            assertEquals(500.0, saved.captured.costPerView)
            assertEquals(325.0, saved.captured.rewardPerUser)
            assertEquals(35, saved.captured.commissionPercent)
        }

        @Test
        fun `both targetViewers and rewardPerUser is 400`() {
            assertBadRequest(CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(targetViewers = 1_000, rewardPerUser = 700.0))
            }
            verify(exactly = 0) { campaigns.save(any()) }
        }

        @Test
        fun `neither targetViewers nor rewardPerUser is 400`() {
            assertBadRequest("Үзэгчийн тоо эсвэл нэг үзэгчийн урамшууллын аль нэгийг оруулна уу") {
                campaignSvc.create(principal.userId, videoReq())
            }
            verify(exactly = 0) { campaigns.save(any()) }
        }

        @Test
        fun `budget too small is 400 with the Mongolian pricing message`() {
            assertBadRequest("Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 500.0, targetViewers = 1_000))
            }
            assertBadRequest("Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 500.0, rewardPerUser = 700.0))
            }
            verify(exactly = 0) { campaigns.save(any()) }
        }

        @Test
        fun `reward below the admin minimum is 400 and names the minimum`() {
            settings(minReward = 150)
            // 100,000 / 1,000 = 100 → R = 70 < 150
            assertBadRequest("Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 100_000.0, targetViewers = 1_000))
            }
            assertBadRequest("Нэг үзэгчид олгох урамшуулал хамгийн багадаа 150 ₮ байх ёстой") {
                campaignSvc.create(principal.userId, videoReq(rewardPerUser = 149.0))
            }
        }

        @Test
        fun `missing or zero budget is 400 BUDGET_INVALID`() {
            assertBadRequest("Нийт төсвөө оруулна уу") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = null, targetViewers = 1_000))
            }
            assertBadRequest("Нийт төсвөө оруулна уу") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 0.0, targetViewers = 1_000))
            }
            assertBadRequest("Нийт төсвөө оруулна уу") {
                campaignSvc.create(principal.userId, videoReq(totalBudget = -1.0, targetViewers = 1_000))
            }
        }

        @Test
        fun `zero viewers is 400 VIEWERS_INVALID, zero reward is 400 REWARD_INVALID`() {
            assertBadRequest("Үзэгчийн тоогоо оруулна уу") {
                campaignSvc.create(principal.userId, videoReq(targetViewers = 0))
            }
            assertBadRequest("Нэг үзэгчид олгох урамшууллаа оруулна уу") {
                campaignSvc.create(principal.userId, videoReq(rewardPerUser = 0.0))
            }
        }

        @Test
        fun `fractional tögrög is 400`() {
            assertBadRequest(CompanyMessages.WHOLE_TUGRIK_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 1_000_000.5, targetViewers = 1_000))
            }
            assertBadRequest(CompanyMessages.WHOLE_TUGRIK_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(rewardPerUser = 700.25))
            }
        }

        @Test
        fun `absurd budget is 400 instead of overflowing`() {
            assertBadRequest(CompanyMessages.AMOUNT_TOO_LARGE_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 1e18, targetViewers = 1_000))
            }
        }

        @Test
        fun `REWARD mode that would need more viewers than fit in an INT is 400`() {
            // 10^15 ₮ at 100 ₮ reward (C = 143) → ~7·10^12 viewers.
            assertBadRequest(CompanyMessages.TOO_MANY_VIEWERS_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(totalBudget = 1e15, rewardPerUser = 100.0))
            }
        }

        @Test
        fun `server-computed cost is saved - the client cannot choose costPerView`() {
            // CreateCampaignReq has no costPerView field at all; whatever the
            // client sends there is dropped by Jackson (see the integration
            // test for the JSON path). The saved price is always C from pricing.
            assertTrue(CreateCampaignReq::class.members.none { it.name == "costPerView" })
            val saved = captureSave()
            campaignSvc.create(principal.userId, videoReq(targetViewers = 2_000))
            assertEquals(500.0, saved.captured.costPerView)
            assertEquals(350.0, saved.captured.rewardPerUser)
        }

        @Test
        fun `video campaign with duration outside 5-180 is 400`() {
            assertBadRequest(CompanyMessages.DURATION_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(targetViewers = 1_000, durationSeconds = 3))
            }
            assertBadRequest(CompanyMessages.DURATION_MESSAGE) {
                campaignSvc.create(principal.userId, videoReq(targetViewers = 1_000, durationSeconds = 181))
            }
        }

        @Test
        fun `survey-only campaign uses the same pricing, blanks video fields`() {
            val saved = captureSave(88L)
            val body = CreateCampaignReq(
                title = "Судалгаа: Хэрэглэгчийн үзэл бодол",
                hasVideo = false, videoUrl = "should-be-ignored",
                durationSeconds = 45, // forced to 0
                totalBudget = 200_000.0,
                targetViewers = 500,
                questions = listOf(
                    CreateCampaignReq.NewQuestion(
                        prompt = "Танай брэндийг таньж байна уу?",
                        type = "SINGLE_CHOICE", options = listOf("Тийм", "Үгүй"),
                    ),
                ),
            )
            val dto = campaignSvc.create(principal.userId, body)

            assertEquals(88L, dto.id)
            assertEquals(false, dto.hasVideo)
            assertEquals(0, saved.captured.durationSeconds)
            assertEquals("", saved.captured.videoUrl)
            assertEquals(400.0, saved.captured.costPerView)   // 200,000 / 500
            assertEquals(280.0, saved.captured.rewardPerUser) // 70 %
            assertEquals(CampaignStatus.AWAITING_PAYMENT, saved.captured.status)
        }

        @Test
        fun `survey-only campaign with no questions is 400`() {
            val body = CreateCampaignReq(
                title = "empty-survey", hasVideo = false,
                totalBudget = 100_000.0, targetViewers = 100,
            )
            assertBadRequest(CompanyMessages.NO_QUESTIONS_MESSAGE) {
                campaignSvc.create(principal.userId, body)
            }
        }
    }

    // ------- pay -------------------------------------------------------------

    @Nested
    inner class Pay {

        private fun awaiting(id: Long = 42L, ownerId: Long = 500L) =
            sampleCampaign(id, ownerId = ownerId, status = CampaignStatus.AWAITING_PAYMENT).apply {
                totalBudget = 999_570.0
                remainingBudget = 999_570.0
            }

        @Test
        fun `happy path marks PENDING and records a SIMULATED PAID payment`() {
            every { campaigns.findById(42L) } returns Optional.of(awaiting())
            every { campaigns.tryMarkPaid(42L, any()) } returns 1
            val payment = slot<CampaignPaymentEntity>()
            every { payments.saveAndFlush(capture(payment)) } answers {
                payment.captured.also { it.id = 9L }
            }

            val res = paymentSvc.pay(principal.userId, 42L)

            val p = payment.captured
            assertEquals(42L, p.campaignId)
            assertEquals(500L, p.companyId)
            assertEquals(999_570.0, p.amount)
            assertEquals(PaymentProvider.SIMULATED, p.provider)
            assertEquals(PaymentStatus.PAID, p.status)
            assertNotNull(p.paidAt)
            assertEquals(PaymentReference.of(42L, p.paidAt!!), p.reference)
            assertTrue(p.reference.matches(Regex("UZ-\\d{8}-42")), p.reference)

            assertEquals(CampaignStatus.PENDING, res.campaign.status)
            assertEquals(p.paidAt, res.campaign.paidAt)
            assertEquals(9L, res.payment.id)
            assertEquals("T42", res.payment.campaignTitle)
            assertEquals(999_570.0, res.payment.amount)
            verify(exactly = 1) { campaigns.tryMarkPaid(42L, p.paidAt!!) }
            verify(exactly = 0) { campaigns.save(any()) }
        }

        @Test
        fun `404 when the campaign does not exist`() {
            every { campaigns.findById(any()) } returns Optional.empty()
            val ex = assertFailsWithHttp { paymentSvc.pay(principal.userId, 1L) }
            assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
        }

        @Test
        fun `403 for another company's campaign - nothing is marked paid`() {
            every { campaigns.findById(42L) } returns Optional.of(awaiting(ownerId = 999L))
            val ex = assertFailsWithHttp { paymentSvc.pay(principal.userId, 42L) }
            assertEquals(HttpStatus.FORBIDDEN, ex.statusCode)
            verify(exactly = 0) { campaigns.tryMarkPaid(any(), any()) }
            verify(exactly = 0) { payments.saveAndFlush(any()) }
        }

        @ParameterizedTest
        @CsvSource("PENDING", "ACTIVE", "PAUSED", "COMPLETED", "REJECTED")
        fun `409 unless AWAITING_PAYMENT`(status: CampaignStatus) {
            every { campaigns.findById(42L) } returns Optional.of(sampleCampaign(42L, status = status))
            val ex = assertFailsWithHttp { paymentSvc.pay(principal.userId, 42L) }
            assertEquals(HttpStatus.CONFLICT, ex.statusCode)
            assertEquals(CompanyMessages.NOT_PAYABLE_MESSAGE, ex.reason)
            verify(exactly = 0) { campaigns.tryMarkPaid(any(), any()) }
        }

        @Test
        fun `409 when a concurrent payment won the conditional update`() {
            every { campaigns.findById(42L) } returns Optional.of(awaiting())
            every { campaigns.tryMarkPaid(42L, any()) } returns 0
            val ex = assertFailsWithHttp { paymentSvc.pay(principal.userId, 42L) }
            assertEquals(HttpStatus.CONFLICT, ex.statusCode)
            verify(exactly = 0) { payments.saveAndFlush(any()) }
        }

        @Test
        fun `409 when the one-PAID-row unique index fires`() {
            every { campaigns.findById(42L) } returns Optional.of(awaiting())
            every { campaigns.tryMarkPaid(42L, any()) } returns 1
            every { payments.saveAndFlush(any()) } throws
                    DataIntegrityViolationException("ux_campaign_payments_one_paid")
            val ex = assertFailsWithHttp { paymentSvc.pay(principal.userId, 42L) }
            assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        }

        @Test
        fun `503 when simulated payments are switched off`() {
            every { campaigns.findById(42L) } returns Optional.of(awaiting())
            val ex = assertFailsWithHttp {
                paymentService(simulated = false).pay(principal.userId, 42L)
            }
            assertEquals(HttpStatus.SERVICE_UNAVAILABLE, ex.statusCode)
            assertEquals("Төлбөрийн систем хараахан холбогдоогүй байна", ex.reason)
            verify(exactly = 0) { campaigns.tryMarkPaid(any(), any()) }
            verify(exactly = 0) { payments.saveAndFlush(any()) }
        }

        @Test
        fun `payment reference uses the Ulaanbaatar calendar date`() {
            // 20:00 UTC on the 28th is already 04:00 on the 29th in Ulaanbaatar (UTC+8).
            val at = OffsetDateTime.of(2026, 9, 28, 20, 0, 0, 0, ZoneOffset.UTC)
            assertEquals("UZ-20260929-42", PaymentReference.of(42L, at))
            val morning = OffsetDateTime.of(2026, 9, 28, 1, 0, 0, 0, ZoneOffset.UTC)
            assertEquals("UZ-20260928-7", PaymentReference.of(7L, morning))
        }
    }

    // ------- payments list ---------------------------------------------------

    @Nested
    inner class Payments {

        @Test
        fun `lists only the caller's payments, newest first, with campaign titles`() {
            val now = OffsetDateTime.now()
            every { payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L) } returns listOf(
                CampaignPaymentEntity(id = 2L, campaignId = 11L, companyId = 500L, amount = 500_000.0,
                    reference = "UZ-20260928-11", createdAt = now, paidAt = now),
                CampaignPaymentEntity(id = 1L, campaignId = 10L, companyId = 500L, amount = 1_000_000.0,
                    reference = "UZ-20260927-10", createdAt = now.minusDays(1), paidAt = now.minusDays(1)),
            )
            every { campaigns.findAllById(listOf(11L, 10L)) } returns
                    listOf(sampleCampaign(10L), sampleCampaign(11L))

            val list = paymentSvc.list(principal.userId)

            assertEquals(listOf(2L, 1L), list.map { it.id })
            assertEquals("T11", list[0].campaignTitle)
            assertEquals("T10", list[1].campaignTitle)
            assertEquals(PaymentStatus.PAID, list[0].status)
            assertEquals(PaymentProvider.SIMULATED, list[0].provider)
            verify(exactly = 1) { payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L) }
            verify(exactly = 0) { payments.findAll() }
        }

        @Test
        fun `empty when the company has never paid`() {
            every { payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L) } returns emptyList()
            every { campaigns.findAllById(emptyList()) } returns emptyList()
            assertTrue(paymentSvc.list(principal.userId).isEmpty())
        }
    }

    // ------- setStatus -------------------------------------------------------

    @Nested
    inner class SetStatus {

        @ParameterizedTest
        @CsvSource(
            "ACTIVE, PAUSED",
            "PAUSED, ACTIVE",
            "ACTIVE, COMPLETED",
            "PAUSED, COMPLETED",
        )
        fun `allowed company transitions`(from: CampaignStatus, to: CampaignStatus) {
            every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1, status = from))
            every { campaigns.tryTransition(1L, from, to, any()) } returns 1

            val dto = campaignSvc.setStatus(principal.userId, 1L, to)

            assertEquals(to, dto.status)
            verify(exactly = 1) { campaigns.tryTransition(1L, from, to, any()) }
            // Never a full-entity save: it would overwrite remaining_budget.
            verify(exactly = 0) { campaigns.save(any()) }
        }

        @ParameterizedTest
        @CsvSource(
            "PENDING, ACTIVE",           // would skip moderation
            "AWAITING_PAYMENT, ACTIVE",  // would skip payment + moderation
            "AWAITING_PAYMENT, PENDING", // would skip payment
            "AWAITING_PAYMENT, PAUSED",
            "PENDING, PAUSED",
            "ACTIVE, PENDING",
            "ACTIVE, AWAITING_PAYMENT",
            "ACTIVE, REJECTED",
            "ACTIVE, ACTIVE",
            "COMPLETED, ACTIVE",
            "REJECTED, ACTIVE",
            "PAUSED, PAUSED",
        )
        fun `denied company transitions are 409`(from: CampaignStatus, to: CampaignStatus) {
            every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1, status = from))
            val ex = assertFailsWithHttp {
                campaignSvc.setStatus(principal.userId, 1L, to)
            }
            assertEquals(HttpStatus.CONFLICT, ex.statusCode)
            assertEquals("Энэ төлөвөөс шилжих боломжгүй", ex.reason)
            verify(exactly = 0) { campaigns.tryTransition(any(), any(), any(), any()) }
        }

        @Test
        fun `409 when the status changed between read and update`() {
            every { campaigns.findById(1L) } returns
                    Optional.of(sampleCampaign(1, status = CampaignStatus.PAUSED))
            every { campaigns.tryTransition(1L, CampaignStatus.PAUSED, CampaignStatus.ACTIVE, any()) } returns 0
            val ex = assertFailsWithHttp {
                campaignSvc.setStatus(principal.userId, 1L, CampaignStatus.ACTIVE)
            }
            assertEquals(HttpStatus.CONFLICT, ex.statusCode)
        }

        @Test
        fun `403 for non-owner`() {
            every { campaigns.findById(1L) } returns Optional.of(sampleCampaign(1, ownerId = 999L))
            val ex = assertFailsWithHttp {
                campaignSvc.setStatus(principal.userId, 1L, CampaignStatus.PAUSED)
            }
            assertEquals(HttpStatus.FORBIDDEN, ex.statusCode)
        }

        @Test
        fun `404 when missing`() {
            every { campaigns.findById(any()) } returns Optional.empty()
            val ex = assertFailsWithHttp {
                campaignSvc.setStatus(principal.userId, 1L, CampaignStatus.PAUSED)
            }
            assertEquals(HttpStatus.NOT_FOUND, ex.statusCode)
        }
    }
}
