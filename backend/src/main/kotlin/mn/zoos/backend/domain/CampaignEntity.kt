package mn.zoos.backend.domain

import jakarta.persistence.*
import org.hibernate.annotations.JdbcTypeCode
import org.hibernate.type.SqlTypes
import java.time.OffsetDateTime

enum class CampaignStatus { PENDING, ACTIVE, PAUSED, COMPLETED, REJECTED }
enum class TargetGender { ALL, MALE, FEMALE }

@Entity
@Table(name = "campaigns")
class CampaignEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "company_id", nullable = false)
    var companyId: Long = 0,

    @Column(nullable = false, length = 200)
    var title: String = "",

    @Column(name = "video_url", nullable = false, length = 500)
    var videoUrl: String = "",

    @Column(name = "thumbnail_url", length = 500)
    var thumbnailUrl: String? = null,

    @Column(name = "duration_seconds", nullable = false)
    var durationSeconds: Int = 30,

    @Enumerated(EnumType.STRING) @Column(name = "target_gender", nullable = false, length = 10)
    var targetGender: TargetGender = TargetGender.ALL,

    @Column(name = "min_age", nullable = false) var minAge: Int = 0,
    @Column(name = "max_age", nullable = false) var maxAge: Int = 100,

    @Column(name = "target_city", nullable = false, length = 50)
    var targetCity: String = "ALL",

    @Column(name = "total_budget", nullable = false)
    var totalBudget: Double = 0.0,

    @Column(name = "remaining_budget", nullable = false)
    var remainingBudget: Double = 0.0,

    @Column(name = "cost_per_view", nullable = false)
    var costPerView: Double = 0.0,

    @Column(name = "reward_per_user", nullable = false)
    var rewardPerUser: Double = 0.0,

    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    var status: CampaignStatus = CampaignStatus.PENDING,

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "updated_at", nullable = false)
    var updatedAt: OffsetDateTime = OffsetDateTime.now(),
)

@Entity
@Table(name = "survey_questions")
class SurveyQuestionEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "campaign_id", nullable = false)
    var campaignId: Long = 0,

    @Column(nullable = false)
    var position: Int = 0,

    @Column(nullable = false, columnDefinition = "TEXT")
    var prompt: String = "",

    @Column(name = "q_type", nullable = false, length = 20)
    var qType: String = "SINGLE_CHOICE",

    /** JSON array of option strings, stored as JSONB. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "options_json", nullable = false, columnDefinition = "jsonb")
    var optionsJson: String = "[]",

    @Column(nullable = false)
    var required: Boolean = true,
)

@Entity
@Table(name = "view_history")
class ViewHistoryEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "user_id", nullable = false)
    var userId: Long = 0,

    @Column(name = "campaign_id", nullable = false)
    var campaignId: Long = 0,

    @Column(name = "reward_paid", nullable = false)
    var rewardPaid: Double = 0.0,

    @Column(name = "watched_at", nullable = false, updatable = false)
    var watchedAt: OffsetDateTime = OffsetDateTime.now(),
)

@Entity
@Table(name = "survey_responses")
class SurveyResponseEntity(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    var id: Long? = null,

    @Column(name = "view_id", nullable = false)
    var viewId: Long = 0,

    @Column(name = "question_id", nullable = false)
    var questionId: Long = 0,

    /** JSONB — could be a string, an array of strings, or an object. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "answer_json", nullable = false, columnDefinition = "jsonb")
    var answerJson: String = "\"\"",

    @Column(name = "created_at", nullable = false, updatable = false)
    var createdAt: OffsetDateTime = OffsetDateTime.now(),
)
