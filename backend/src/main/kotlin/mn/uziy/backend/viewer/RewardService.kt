package mn.uziy.backend.viewer

import mn.uziy.backend.common.ConflictException
import mn.uziy.backend.common.NotFoundException
import mn.uziy.backend.domain.*
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Isolation
import org.springframework.transaction.annotation.Transactional

/** The reward use case: a viewer finishes a survey and gets paid. */
interface RewardService {
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
    fun submitSurvey(userId: Long, campaignId: Long, answers: List<SubmitSurveyReq.Answer>): RewardResult
}

@Service
class RewardServiceImpl(
    private val users: UserRepository,
    private val campaigns: CampaignRepository,
    private val questions: SurveyQuestionRepository,
    private val history: ViewHistoryRepository,
    private val responses: SurveyResponseRepository,
) : RewardService {

    @Transactional(isolation = Isolation.SERIALIZABLE)
    override fun submitSurvey(
        userId: Long,
        campaignId: Long,
        answers: List<SubmitSurveyReq.Answer>,
    ): RewardResult {
        if (history.existsByUserIdAndCampaignId(userId, campaignId))
            throw ConflictException("Already rewarded for this campaign")

        val campaign = campaigns.findById(campaignId).orElseThrow {
            NotFoundException("Campaign not found")
        }

        if (campaigns.tryDecrementBudget(campaign.id!!) == 0)
            throw ConflictException("Campaign no longer available")

        val view = history.save(ViewHistoryEntity(
            userId = userId,
            campaignId = campaign.id!!,
            rewardPaid = campaign.rewardPerUser,
        ))

        recordAnswers(view.id!!, campaign.id!!, answers)

        val user = users.findById(userId).orElseThrow()
        user.balance += campaign.rewardPerUser
        users.save(user)

        return RewardResult(rewardPaid = campaign.rewardPerUser, newBalance = user.balance)
    }

    /** Answers to questions that don't belong to this campaign are ignored. */
    private fun recordAnswers(viewId: Long, campaignId: Long, answers: List<SubmitSurveyReq.Answer>) {
        val validQuestionIds = questions
            .findAllByCampaignIdOrderByPosition(campaignId)
            .map { it.id!! }
            .toSet()
        for (a in answers) {
            if (a.questionId !in validQuestionIds) continue
            responses.save(SurveyResponseEntity(
                viewId = viewId,
                questionId = a.questionId,
                answerJson = a.answerJson.ifBlank { "\"\"" },
            ))
        }
    }
}
