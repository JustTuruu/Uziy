package mn.uziy.backend.company

import com.fasterxml.jackson.annotation.JsonIgnoreProperties
import jakarta.validation.constraints.NotBlank
import mn.uziy.backend.domain.*
import java.time.OffsetDateTime

data class CampaignDto(
    val id: Long,
    val title: String,
    val videoUrl: String,
    val durationSeconds: Int,
    val hasVideo: Boolean,
    val targetGender: TargetGender,
    val minAge: Int,
    val maxAge: Int,
    val targetCity: String,
    /** Amount charged (= payable P), whole ₮. */
    val totalBudget: Double,
    val remainingBudget: Double,
    /** C — what one viewer costs the company (reward + platform commission). */
    val costPerView: Double,
    /** R — what one viewer receives. */
    val rewardPerUser: Double,
    val status: CampaignStatus,
    val createdAt: OffsetDateTime,
    /** N — viewers the budget buys. */
    val targetViewers: Int?,
    /** Commission snapshot at creation; null for legacy (pre-V5) campaigns. */
    val commissionPercent: Int?,
    val paidAt: OffsetDateTime?,
) {
    companion object {
        fun of(c: CampaignEntity) = CampaignDto(
            id = c.id!!, title = c.title, videoUrl = c.videoUrl,
            durationSeconds = c.durationSeconds,
            hasVideo = c.hasVideo,
            targetGender = c.targetGender,
            minAge = c.minAge, maxAge = c.maxAge, targetCity = c.targetCity,
            totalBudget = c.totalBudget, remainingBudget = c.remainingBudget,
            costPerView = c.costPerView, rewardPerUser = c.rewardPerUser,
            status = c.status, createdAt = c.createdAt,
            targetViewers = c.targetViewers,
            commissionPercent = c.commissionPercent,
            paidAt = c.paidAt,
        )
    }
}

/**
 * Pricing inputs: `totalBudget` plus EXACTLY ONE of `targetViewers` (VIEWERS
 * mode) or `rewardPerUser` (REWARD mode). The server derives everything else
 * with the current platform commission — cost-per-view is never taken from
 * the client (an unknown `costPerView` field in the JSON is ignored).
 */
@JsonIgnoreProperties(ignoreUnknown = true)
data class CreateCampaignReq(
    @field:NotBlank val title: String,
    val videoUrl: String = "",
    /** Set false for survey-only campaigns (videoUrl + durationSeconds ignored). */
    val hasVideo: Boolean = true,
    val durationSeconds: Int = 0,
    val targetGender: TargetGender = TargetGender.ALL,
    val minAge: Int = 0,
    val maxAge: Int = 100,
    val targetCity: String = "ALL",
    /** B, whole ₮. Nullable so a missing value gets the Mongolian pricing message. */
    val totalBudget: Double? = null,
    val targetViewers: Int? = null,
    /** R, whole ₮. */
    val rewardPerUser: Double? = null,
    val questions: List<NewQuestion> = emptyList(),
) {
    data class NewQuestion(
        val prompt: String,
        val type: String,          // SINGLE_CHOICE | MULTI_CHOICE | TEXT
        val options: List<String> = emptyList(),
        val required: Boolean = true,
    )
}

data class PaymentDto(
    val id: Long,
    val campaignId: Long,
    val campaignTitle: String,
    val amount: Double,
    val provider: PaymentProvider,
    val status: PaymentStatus,
    val reference: String,
    val createdAt: OffsetDateTime,
    val paidAt: OffsetDateTime?,
) {
    companion object {
        fun of(p: CampaignPaymentEntity, campaignTitle: String) = PaymentDto(
            id = p.id!!, campaignId = p.campaignId, campaignTitle = campaignTitle,
            amount = p.amount, provider = p.provider, status = p.status,
            reference = p.reference, createdAt = p.createdAt, paidAt = p.paidAt,
        )
    }
}

data class PayCampaignResponse(val campaign: CampaignDto, val payment: PaymentDto)
