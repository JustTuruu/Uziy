package mn.uziy.backend.viewer

import mn.uziy.backend.auth.Me
import mn.uziy.backend.domain.CampaignRepository
import mn.uziy.backend.domain.SurveyQuestionRepository
import mn.uziy.backend.domain.TargetGender
import mn.uziy.backend.domain.UserRepository
import org.springframework.stereotype.Service

/** Read-side use cases of the viewer app: profile, home feed, survey questions. */
interface ViewerService {
    fun me(userId: Long): Me

    /**
     * Home feed. Spec §4B — ACTIVE campaigns matching demographics that this
     * user hasn't watched, with enough budget for at least one more view.
     */
    fun feed(userId: Long): List<FeedItemDto>

    fun questions(campaignId: Long): List<QuestionDto>
}

@Service
class ViewerServiceImpl(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
) : ViewerService {

    override fun me(userId: Long): Me = Me.of(users.findById(userId).orElseThrow())

    override fun feed(userId: Long): List<FeedItemDto> {
        val user = users.findById(userId).orElseThrow()
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
                hasVideo = it.hasVideo,
                rewardPerUser = it.rewardPerUser,
                companyName = companyNames[it.companyId] ?: "",
            )
        }
    }

    override fun questions(campaignId: Long): List<QuestionDto> =
        questions.findAllByCampaignIdOrderByPosition(campaignId).map {
            QuestionDto(
                id = it.id!!,
                position = it.position,
                prompt = it.prompt,
                type = it.qType,
                options = parseOptions(it.optionsJson),
                required = it.required,
            )
        }

    private fun parseOptions(json: String): List<String> = runCatching {
        // Cheap parser sufficient for JSONB array of strings.
        json.trim().removePrefix("[").removeSuffix("]")
            .split(",")
            .map { it.trim().trim('"') }
            .filter { it.isNotBlank() }
    }.getOrDefault(emptyList())
}
