package mn.uziy.backend.payment

import mn.uziy.backend.config.AppProperties
import mn.uziy.backend.domain.PaymentProvider
import org.springframework.stereotype.Component
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Dev/test gateway: no money moves, the charge "succeeds" instantly. Only
 * available when `uziy.payments.simulated` is true (defaults to false so a
 * missing property can never hand out free campaigns).
 */
@Component
class SimulatedPaymentGateway(private val props: AppProperties) : PaymentGateway {

    override val provider = PaymentProvider.SIMULATED

    override fun isAvailable() = props.payments.simulated

    override fun charge(request: ChargeRequest) =
        ChargeResult(PaymentReference.of(request.campaignId, request.at))
}

object PaymentReference {
    private val ZONE: ZoneId = ZoneId.of("Asia/Ulaanbaatar")
    private val DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd")

    /** Invoice number shown to the company: UZ-<yyyyMMdd in Ulaanbaatar>-<campaignId>. */
    fun of(campaignId: Long, at: OffsetDateTime): String =
        "UZ-${at.atZoneSameInstant(ZONE).format(DATE)}-$campaignId"
}
