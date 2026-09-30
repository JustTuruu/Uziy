package mn.uziy.backend.payout

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Positive
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
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

@RestController
class PayoutController(
    private val payouts: PayoutRepository,
    private val users: UserRepository,
) {

    private fun toDto(p: PayoutEntity, phone: String) = PayoutDto(
        id = p.id!!, userId = p.userId, userPhone = phone,
        amount = p.amount, bank = p.bank, accountNumber = p.accountNumber,
        accountName = p.accountName, nationalId = p.nationalId,
        status = p.status, isFirstPayout = p.isFirstPayout,
        requestedAt = p.requestedAt, decidedAt = p.decidedAt,
        rejectReason = p.rejectReason,
    )

    // --- Viewer side ---------------------------------------------------------

    @PostMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    @Transactional
    fun request(
        @Valid @RequestBody body: CreatePayoutReq,
        @Auth principal: JwtPrincipal,
    ): PayoutDto {
        val user = users.findById(principal.userId).orElseThrow()
        if (user.balance < body.amount)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Insufficient balance")

        // Any prior APPROVED payout ⇒ not a first payout.
        val isFirst = !payouts.existsByUserIdAndStatus(user.id!!, PayoutStatus.APPROVED)

        // Reserve the amount by decrementing balance immediately so it can't
        // be spent twice while the request is PENDING. Refund on rejection.
        user.balance -= body.amount
        users.save(user)

        val saved = payouts.save(PayoutEntity(
            userId = user.id!!,
            amount = body.amount,
            bank = body.bank,
            accountNumber = body.accountNumber,
            accountName = body.accountName,
            nationalId = body.nationalId,
            isFirstPayout = isFirst,
        ))
        return toDto(saved, user.phoneNumber)
    }

    @GetMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    fun mine(@Auth principal: JwtPrincipal): List<PayoutDto> {
        val user = users.findById(principal.userId).orElseThrow()
        return payouts.findAllByUserIdOrderByRequestedAtDesc(user.id!!)
            .map { toDto(it, user.phoneNumber) }
    }

    // --- Admin side ----------------------------------------------------------

    @GetMapping("/admin/payouts")
    @PreAuthorize("hasRole('ADMIN')")
    fun pending(): List<PayoutDto> {
        val list = payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING)
        val phoneById = users.findAllById(list.map { it.userId }.distinct())
            .associate { it.id!! to it.phoneNumber }
        return list.map { toDto(it, phoneById[it.userId] ?: "") }
    }

    /**
     * Decided payouts (approved + rejected), newest-first. Used by the
     * admin console's payout-history table so old requests are still
     * visible after refresh, not just the ones decided this session.
     */
    @GetMapping("/admin/payouts/history")
    @PreAuthorize("hasRole('ADMIN')")
    fun history(): List<PayoutDto> {
        val list = payouts.findAllByStatusInOrderByDecidedAtDesc(
            listOf(PayoutStatus.APPROVED, PayoutStatus.REJECTED),
        )
        val phoneById = users.findAllById(list.map { it.userId }.distinct())
            .associate { it.id!! to it.phoneNumber }
        return list.map { toDto(it, phoneById[it.userId] ?: "") }
    }

    /**
     * Approve or reject. Spec §4A: on APPROVED (first payout only) also
     * flip users.is_verified = TRUE. On REJECTED refund the reserved balance.
     */
    @PatchMapping("/admin/payouts/{id}/decision")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    fun decide(
        @PathVariable id: Long,
        @RequestParam decision: PayoutStatus,
        @RequestParam(required = false) reason: String?,
        @Auth principal: JwtPrincipal,
    ): PayoutDto {
        if (decision == PayoutStatus.PENDING)
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Cannot set PENDING")

        val p = payouts.findById(id).orElseThrow()
        if (p.status != PayoutStatus.PENDING)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Already decided")

        val user = users.findById(p.userId).orElseThrow()
        when (decision) {
            PayoutStatus.APPROVED -> {
                if (p.isFirstPayout) user.isVerified = true
                users.save(user)
            }
            PayoutStatus.REJECTED -> {
                user.balance += p.amount // refund the reservation
                users.save(user)
            }
            PayoutStatus.PENDING -> Unit
        }

        p.status = decision
        p.rejectReason = reason?.takeIf { decision == PayoutStatus.REJECTED }
        p.decidedBy = principal.userId
        p.decidedAt = OffsetDateTime.now()
        return toDto(payouts.save(p), user.phoneNumber)
    }
}
