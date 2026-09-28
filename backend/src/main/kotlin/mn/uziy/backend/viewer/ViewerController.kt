package mn.uziy.backend.viewer

import jakarta.validation.Valid
import jakarta.validation.constraints.NotEmpty
import mn.uziy.backend.auth.Me
import mn.uziy.backend.domain.*
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.http.HttpStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.transaction.annotation.Isolation
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException

data class FeedItemDto(
    val id: Long,
    val title: String,
    val videoUrl: String,
    val thumbnailUrl: String?,
    val durationSeconds: Int,
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

@RestController
@RequestMapping("/viewer")
@PreAuthorize("hasRole('VIEWER')")
class ViewerController(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
    private val history: ViewHistoryRepository,
    private val responses: SurveyResponseRepository,
) {

    @GetMapping("/me")
    fun me(@Auth principal: JwtPrincipal): Me =
        Me.of(users.findById(principal.userId).orElseThrow())

    /**
     * Home feed. Spec §4B — ACTIVE campaigns matching demographics that this
     * user hasn't watched, with enough budget for at least one more view.
     */
    @GetMapping("/feed")
    fun feed(@Auth principal: JwtPrincipal): List<FeedItemDto> {
        val user = users.findById(principal.userId).orElseThrow()
        if (user.gender == null || user.age == null || user.city == null) return emptyList()

        val list = campaigns.findFeedFor(
            userId = user.id!!,
            userGender = TargetGender.valueOf(user.gender!!.name),
            userAge = user.age!!,
            userCity = user.city!!,
        )
        val companyNames = users
            .findAllById(list.map { it.companyId }.distinct())
            .associate { it.id!! to (it.companyName ?: "") }
        return list.map {
            FeedItemDto(
                id = it.id!!,
                title = it.title,
                videoUrl = it.videoUrl,
                thumbnailUrl = it.thumbnailUrl,
                durationSeconds = it.durationSeconds,
                rewardPerUser = it.rewardPerUser,
                companyName = companyNames[it.companyId] ?: "",
            )
        }
    }

    @GetMapping("/campaigns/{id}/questions")
    fun questions(@PathVariable id: Long): List<QuestionDto> =
        questions.findAllByCampaignIdOrderByPosition(id).map {
            QuestionDto(
                id = it.id!!,
                position = it.position,
                prompt = it.prompt,
                type = it.qType,
                options = parseOptions(it.optionsJson),
                required = it.required,
            )
        }

    /**
     * SPEC §4C — the atomic reward transaction.
     *
     * 1. Ensure the user hasn't already been rewarded for this campaign.
     * 2. Conditionally decrement the campaign's remaining_budget.
     *    (Skips if paused, budget too low, or another request beat us.)
     * 3. Insert view_history + survey_responses.
     * 4. Credit the viewer's balance.
     *
     * SERIALIZABLE isolation prevents concurrent submissions from both
     * seeing "enough budget" and both crediting the user. If anything fails,
     * everything rolls back — no partial reward.
     */
    @PostMapping("/campaigns/{id}/submit")
    @Transactional(isolation = Isolation.SERIALIZABLE)
    fun submit(
        @PathVariable id: Long,
        @Valid @RequestBody body: SubmitSurveyReq,
        @Auth principal: JwtPrincipal,
    ): RewardResult {
        val userId = principal.userId
        if (history.existsByUserIdAndCampaignId(userId, id))
            throw ResponseStatusException(HttpStatus.CONFLICT, "Already rewarded for this campaign")

        val campaign = campaigns.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "Campaign not found")
        }

        val decremented = campaigns.tryDecrementBudget(campaign.id!!)
        if (decremented == 0)
            throw ResponseStatusException(HttpStatus.CONFLICT, "Campaign no longer available")

        val view = history.save(ViewHistoryEntity(
            userId = userId,
            campaignId = campaign.id!!,
            rewardPaid = campaign.rewardPerUser,
        ))

        val validQuestionIds = questions
            .findAllByCampaignIdOrderByPosition(campaign.id!!)
            .map { it.id!! }
            .toSet()
        for (a in body.answers) {
            if (a.questionId !in validQuestionIds) continue
            responses.save(SurveyResponseEntity(
                viewId = view.id!!,
                questionId = a.questionId,
                answerJson = a.answerJson.ifBlank { "\"\"" },
            ))
        }

        val user = users.findById(userId).orElseThrow()
        user.balance += campaign.rewardPerUser
        users.save(user)

        return RewardResult(rewardPaid = campaign.rewardPerUser, newBalance = user.balance)
    }

    private fun parseOptions(json: String): List<String> = runCatching {
        // Cheap parser sufficient for JSONB array of strings.
        json.trim().removePrefix("[").removeSuffix("]")
            .split(",")
            .map { it.trim().trim('"') }
            .filter { it.isNotBlank() }
    }.getOrDefault(emptyList())
}
