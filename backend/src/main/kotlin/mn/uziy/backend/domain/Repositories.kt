package mn.uziy.backend.domain

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<UserEntity, Long> {
    fun findByPhoneNumber(phoneNumber: String): UserEntity?
    fun existsByPhoneNumber(phoneNumber: String): Boolean
}

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
}

@Repository
interface SurveyQuestionRepository : JpaRepository<SurveyQuestionEntity, Long> {
    fun findAllByCampaignIdOrderByPosition(campaignId: Long): List<SurveyQuestionEntity>
    fun deleteAllByCampaignId(campaignId: Long)
}

@Repository
interface ViewHistoryRepository : JpaRepository<ViewHistoryEntity, Long> {
    fun existsByUserIdAndCampaignId(userId: Long, campaignId: Long): Boolean
    fun countByUserId(userId: Long): Long
}

@Repository
interface SurveyResponseRepository : JpaRepository<SurveyResponseEntity, Long> {
    fun findAllByQuestionId(questionId: Long): List<SurveyResponseEntity>
}

@Repository
interface PayoutRepository : JpaRepository<PayoutEntity, Long> {
    fun findAllByStatusOrderByRequestedAtAsc(status: PayoutStatus): List<PayoutEntity>
    fun findAllByUserIdOrderByRequestedAtDesc(userId: Long): List<PayoutEntity>
    fun existsByUserIdAndStatus(userId: Long, status: PayoutStatus): Boolean
}
