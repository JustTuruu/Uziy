package mn.uziy.backend.domain

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime

@Repository
interface CampaignRepository : JpaRepository<CampaignEntity, Long> {

    fun findAllByCompanyIdOrderByCreatedAtDesc(companyId: Long): List<CampaignEntity>
    fun findAllByStatusOrderByCreatedAtDesc(status: CampaignStatus): List<CampaignEntity>

    /**
     * Home-feed query — spec §4B.
     * Returns ACTIVE campaigns that (a) match the viewer's demographics,
     * (b) still have budget for at least one more view, (c) haven't already
     * been shown to this user.
     */
    @Query("""
        SELECT c FROM CampaignEntity c
        WHERE c.status = mn.uziy.backend.domain.CampaignStatus.ACTIVE
          AND (c.targetGender = mn.uziy.backend.domain.TargetGender.ALL OR c.targetGender = :userGender)
          AND (:userAge BETWEEN c.minAge AND c.maxAge)
          AND (c.targetCity = 'ALL' OR c.targetCity = :userCity)
          AND c.remainingBudget >= c.costPerView
          AND c.id NOT IN (
              SELECT v.campaignId FROM ViewHistoryEntity v WHERE v.userId = :userId
          )
        ORDER BY c.createdAt DESC
    """)
    fun findFeedFor(
        @Param("userId")     userId: Long,
        @Param("userGender") userGender: TargetGender,
        @Param("userAge")    userAge: Int,
        @Param("userCity")   userCity: String,
    ): List<CampaignEntity>

    /**
     * Atomic budget decrement — decrements iff the campaign still has enough
     * budget AND is ACTIVE. Returns 1 if applied, 0 if not.
     * Used inside the reward transaction (spec §4C) so we can detect races.
     */
    @Modifying
    @Query("""
        UPDATE CampaignEntity c
           SET c.remainingBudget = c.remainingBudget - c.costPerView,
               c.updatedAt       = CURRENT_TIMESTAMP
         WHERE c.id = :campaignId
           AND c.status = mn.uziy.backend.domain.CampaignStatus.ACTIVE
           AND c.remainingBudget >= c.costPerView
    """)
    fun tryDecrementBudget(@Param("campaignId") campaignId: Long): Int

    /**
     * Payment step: AWAITING_PAYMENT → PENDING, stamping paid_at. Conditional
     * on the current status so two concurrent "Төлөх" clicks can't both win —
     * the loser's UPDATE re-checks the row after the winner commits and
     * matches 0 rows. Returns 1 if this call flipped it, 0 otherwise.
     *
     * clearAutomatically: the persistence context is cleared afterwards so a
     * later read in the same transaction can't see the stale pre-update entity.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE CampaignEntity c
           SET c.status    = mn.uziy.backend.domain.CampaignStatus.PENDING,
               c.paidAt    = :paidAt,
               c.updatedAt = :paidAt
         WHERE c.id = :campaignId
           AND c.status = mn.uziy.backend.domain.CampaignStatus.AWAITING_PAYMENT
    """)
    fun tryMarkPaid(
        @Param("campaignId") campaignId: Long,
        @Param("paidAt") paidAt: OffsetDateTime,
    ): Int

    /**
     * Company-driven status change (pause / resume / complete), applied only
     * if the row is still in `from`. Touches status + updated_at ONLY — a
     * full-entity save here would write back a stale remaining_budget while
     * viewers are concurrently being rewarded (tryDecrementBudget), silently
     * refunding views. Returns 1 if applied, 0 if the status moved meanwhile.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
        UPDATE CampaignEntity c
           SET c.status    = :to,
               c.updatedAt = :now
         WHERE c.id = :campaignId
           AND c.status = :from
    """)
    fun tryTransition(
        @Param("campaignId") campaignId: Long,
        @Param("from") from: CampaignStatus,
        @Param("to") to: CampaignStatus,
        @Param("now") now: OffsetDateTime,
    ): Int
}

@Repository
interface CampaignPaymentRepository : JpaRepository<CampaignPaymentEntity, Long> {
    /** A company's payments, newest first (id breaks same-instant ties). */
    fun findAllByCompanyIdOrderByCreatedAtDescIdDesc(companyId: Long): List<CampaignPaymentEntity>
}
