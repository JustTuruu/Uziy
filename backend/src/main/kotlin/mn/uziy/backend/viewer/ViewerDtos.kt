package mn.uziy.backend.viewer

import jakarta.validation.constraints.NotEmpty

data class FeedItemDto(
    val id: Long,
    val title: String,
    val videoUrl: String,
    val thumbnailUrl: String?,
    val durationSeconds: Int,
    val hasVideo: Boolean,
    val rewardPerUser: Double,
    val companyName: String,
)

data class QuestionDto(
    val id: Long,
    val position: Int,
    val prompt: String,
    val type: String,
    val options: List<String>,
    val required: Boolean,
)

data class SubmitSurveyReq(
    @field:NotEmpty val answers: List<Answer>,
) {
    data class Answer(
        val questionId: Long,
        /** Serialized JSON: "text", ["a","b"], "single choice" */
        val answerJson: String,
    )
}

data class RewardResult(val rewardPaid: Double, val newBalance: Double)
