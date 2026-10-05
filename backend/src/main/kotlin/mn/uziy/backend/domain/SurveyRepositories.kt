package mn.uziy.backend.domain

import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime

@Repository
interface SurveyQuestionRepository : JpaRepository<SurveyQuestionEntity, Long> {
    fun findAllByCampaignIdOrderByPosition(campaignId: Long): List<SurveyQuestionEntity>
    fun deleteAllByCampaignId(campaignId: Long)
}

@Repository
interface ViewHistoryRepository : JpaRepository<ViewHistoryEntity, Long> {
    fun existsByUserIdAndCampaignId(userId: Long, campaignId: Long): Boolean
    fun countByUserId(userId: Long): Long
    fun countByCampaignId(campaignId: Long): Long
}

@Repository
interface SurveyResponseRepository : JpaRepository<SurveyResponseEntity, Long> {
    fun findAllByQuestionId(questionId: Long): List<SurveyResponseEntity>
}
