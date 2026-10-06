package mn.uziy.backend.viewer;

import java.util.List;

/** The reward use case: a viewer finishes a survey and gets paid. */
public interface RewardService {
    /**
     * SPEC §4C — the atomic reward transaction.
     *
     * <ol>
     *   <li>Ensure the user hasn't already been rewarded for this campaign.</li>
     *   <li>Conditionally decrement the campaign's remaining_budget.
     *       (Skips if paused, budget too low, or another request beat us.)</li>
     *   <li>Insert view_history + survey_responses.</li>
     *   <li>Credit the viewer's balance.</li>
     * </ol>
     *
     * SERIALIZABLE isolation prevents concurrent submissions from both
     * seeing "enough budget" and both crediting the user. If anything fails,
     * everything rolls back — no partial reward.
     */
    RewardResult submitSurvey(long userId, long campaignId, List<SubmitSurveyReq.Answer> answers);
}
