package mn.uziy.backend.domain

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface PayoutRepository : JpaRepository<PayoutEntity, Long> {
    fun findAllByStatusOrderByRequestedAtAsc(status: PayoutStatus): List<PayoutEntity>
    fun findAllByUserIdOrderByRequestedAtDesc(userId: Long): List<PayoutEntity>
    fun existsByUserIdAndStatus(userId: Long, status: PayoutStatus): Boolean

    /**
     * Decided payouts (APPROVED or REJECTED) newest-first. Used by the
     * admin history table so the super admin sees what was already
     * processed, not just what's still pending.
     */
    fun findAllByStatusInOrderByDecidedAtDesc(
        statuses: Collection<PayoutStatus>,
    ): List<PayoutEntity>
}
