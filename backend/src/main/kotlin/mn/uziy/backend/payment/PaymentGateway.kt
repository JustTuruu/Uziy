package mn.uziy.backend.payment

import mn.uziy.backend.domain.PaymentProvider
import java.time.OffsetDateTime

data class ChargeRequest(
    val campaignId: Long,
    val companyId: Long,
    /** Whole ₮. */
    val amount: Double,
    val at: OffsetDateTime,
)

/** What the company sees on the invoice. */
data class ChargeResult(val reference: String)

/**
 * A way to take a company's money. The payment use case depends only on this
 * interface: supporting a new provider (QPay, bank transfer…) means adding
 * one implementation — no existing code changes.
 */
interface PaymentGateway {
    val provider: PaymentProvider

    /** False while the gateway is not configured / switched on. */
    fun isAvailable(): Boolean

    /** Takes the money, or throws if it could not. */
    fun charge(request: ChargeRequest): ChargeResult
}
