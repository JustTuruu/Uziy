package mn.uziy.backend.payout

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Positive
import mn.uziy.backend.domain.PayoutStatus
import java.time.OffsetDateTime

data class PayoutDto(
    val id: Long,
    val userId: Long,
    val userPhone: String,
    val amount: Double,
    val bank: String,
    val accountNumber: String,
    val accountName: String,
    val nationalId: String,
    val status: PayoutStatus,
    val isFirstPayout: Boolean,
    val requestedAt: OffsetDateTime,
    val decidedAt: OffsetDateTime?,
    val rejectReason: String?,
)

data class CreatePayoutReq(
    @field:Positive val amount: Double,
    @field:NotBlank val bank: String,
    @field:NotBlank val accountNumber: String,
    @field:NotBlank val accountName: String,
    @field:NotBlank val nationalId: String,
)
