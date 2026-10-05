package mn.uziy.backend.payout

import mn.uziy.backend.common.BadRequestException
import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.domain.PayoutEntity
import mn.uziy.backend.domain.PayoutRepository
import mn.uziy.backend.domain.PayoutStatus
import mn.uziy.backend.domain.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime

/** Cash-out use cases: the viewer asks, the super admin decides. */
interface PayoutService {
    /** Reserves [CreatePayoutReq.amount] from the viewer's balance as a PENDING payout. */
    fun request(userId: Long, req: CreatePayoutReq): PayoutDto

    fun mine(userId: Long): List<PayoutDto>

    fun pending(): List<PayoutDto>

    /**
     * Decided payouts (approved + rejected), newest-first, so old requests
     * stay visible after a refresh.
     */
    fun history(): List<PayoutDto>

    /**
     * Approve or reject. Spec §4A: on APPROVED (first payout only) also
     * flip users.is_verified = TRUE. On REJECTED refund the reserved balance.
     */
    fun decide(payoutId: Long, decision: PayoutStatus, reason: String?, adminId: Long): PayoutDto
}

@Service
class PayoutServiceImpl(
    private val payouts: PayoutRepository,
    private val users: UserRepository,
) : PayoutService {

    @Transactional
    override fun request(userId: Long, req: CreatePayoutReq): PayoutDto {
        val user = users.findById(userId).orElseThrow()
        if (user.balance < req.amount) throw BadRequestException("Insufficient balance")

        // Any prior APPROVED payout ⇒ not a first payout.
        val isFirst = !payouts.existsByUserIdAndStatus(user.id!!, PayoutStatus.APPROVED)

        // Reserve the amount by decrementing balance immediately so it can't
        // be spent twice while the request is PENDING. Refund on rejection.
        user.balance -= req.amount
        users.save(user)

        val saved = payouts.save(PayoutEntity(
            userId = user.id!!,
            amount = req.amount,
            bank = req.bank,
            accountNumber = req.accountNumber,
            accountName = req.accountName,
            nationalId = req.nationalId,
            isFirstPayout = isFirst,
        ))
        return toDto(saved, user.phoneNumber)
    }

    override fun mine(userId: Long): List<PayoutDto> {
        val user = users.findById(userId).orElseThrow()
        return payouts.findAllByUserIdOrderByRequestedAtDesc(user.id!!)
            .map { toDto(it, user.phoneNumber) }
    }

    override fun pending(): List<PayoutDto> =
        withPhones(payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING))

    override fun history(): List<PayoutDto> =
        withPhones(payouts.findAllByStatusInOrderByDecidedAtDesc(
            listOf(PayoutStatus.APPROVED, PayoutStatus.REJECTED),
        ))

    @Transactional
    override fun decide(
        payoutId: Long,
        decision: PayoutStatus,
        reason: String?,
        adminId: Long,
    ): PayoutDto {
        if (decision == PayoutStatus.PENDING) throw BadRequestException("Cannot set PENDING")

        val p = payouts.findById(payoutId).orElseThrow()
        if (p.status != PayoutStatus.PENDING) throw ConflictException("Already decided")

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
        p.decidedBy = adminId
        p.decidedAt = OffsetDateTime.now()
        return toDto(payouts.save(p), user.phoneNumber)
    }

    private fun withPhones(list: List<PayoutEntity>): List<PayoutDto> {
        val phoneById = users.findAllById(list.map { it.userId }.distinct())
            .associate { it.id!! to it.phoneNumber }
        return list.map { toDto(it, phoneById[it.userId] ?: "") }
    }

    private fun toDto(p: PayoutEntity, phone: String) = PayoutDto(
        id = p.id!!, userId = p.userId, userPhone = phone,
        amount = p.amount, bank = p.bank, accountNumber = p.accountNumber,
        accountName = p.accountName, nationalId = p.nationalId,
        status = p.status, isFirstPayout = p.isFirstPayout,
        requestedAt = p.requestedAt, decidedAt = p.decidedAt,
        rejectReason = p.rejectReason,
    )
}
