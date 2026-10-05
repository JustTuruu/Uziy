package mn.uziy.backend.payment

import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import mn.uziy.backend.common.UnavailableException
import mn.uziy.backend.company.CampaignPaymentServiceImpl
import mn.uziy.backend.company.CompanyMessages
import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.*
import org.junit.jupiter.api.Test
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.util.Optional
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class PaymentGatewayTest {

    private val at = OffsetDateTime.of(2026, 9, 29, 10, 0, 0, 0, ZoneOffset.UTC)

    private fun simulated(on: Boolean) =
        SimulatedPaymentGateway(AppProperties(payments = AppProperties.Payments(simulated = on)))

    @Test
    fun `simulated gateway is available only when switched on`() {
        assertTrue(simulated(true).isAvailable())
        assertFalse(simulated(false).isAvailable())
    }

    @Test
    fun `simulated gateway reports the SIMULATED provider and an invoice reference`() {
        val g = simulated(true)
        assertEquals(PaymentProvider.SIMULATED, g.provider)
        assertEquals("UZ-20260929-42", g.charge(ChargeRequest(42L, 500L, 1_000.0, at)).reference)
    }

    // --- the payment use case only knows the PaymentGateway interface ---------

    private val campaigns = mockk<CampaignRepository>()
    private val payments = mockk<CampaignPaymentRepository>()

    private fun awaiting() = CampaignEntity(
        id = 42L, companyId = 500L, title = "T", durationSeconds = 30,
        targetGender = TargetGender.ALL, minAge = 18, maxAge = 45, targetCity = "ALL",
        totalBudget = 1_000_000.0, remainingBudget = 1_000_000.0,
        costPerView = 1_000.0, rewardPerUser = 700.0, status = CampaignStatus.AWAITING_PAYMENT,
    )

    private class FakeGateway(
        override val provider: PaymentProvider,
        private val available: Boolean,
    ) : PaymentGateway {
        var charged = 0
        override fun isAvailable() = available
        override fun charge(request: ChargeRequest): ChargeResult {
            charged++
            return ChargeResult("FAKE-${request.campaignId}")
        }
    }

    @Test
    fun `a new provider works without touching the payment service - first available gateway wins`() {
        val off = FakeGateway(PaymentProvider.QPAY, available = false)
        val on = FakeGateway(PaymentProvider.BANK_TRANSFER, available = true)
        every { campaigns.findById(42L) } returns Optional.of(awaiting())
        every { campaigns.tryMarkPaid(42L, any()) } returns 1
        val saved = slot<CampaignPaymentEntity>()
        every { payments.saveAndFlush(capture(saved)) } answers { saved.captured.also { it.id = 7L } }

        val res = CampaignPaymentServiceImpl(campaigns, payments, listOf(off, on)).pay(500L, 42L)

        assertEquals(0, off.charged)
        assertEquals(1, on.charged)
        assertEquals(PaymentProvider.BANK_TRANSFER, saved.captured.provider)
        assertEquals("FAKE-42", res.payment.reference)
    }

    @Test
    fun `no available gateway answers unavailable and marks nothing paid`() {
        every { campaigns.findById(42L) } returns Optional.of(awaiting())

        val ex = assertFailsWith<UnavailableException> {
            CampaignPaymentServiceImpl(campaigns, payments, listOf(FakeGateway(PaymentProvider.QPAY, false)))
                .pay(500L, 42L)
        }
        assertEquals(CompanyMessages.PAYMENTS_UNAVAILABLE_MESSAGE, ex.message)
    }
}
