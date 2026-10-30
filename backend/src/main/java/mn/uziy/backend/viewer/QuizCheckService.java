package mn.uziy.backend.viewer;

/** Lets the app tell a viewer at once whether their QUIZ pick is right, so they can try again. */
public interface QuizCheckService {

    /**
     * @throws mn.uziy.backend.common.NotFoundException the campaign is not running or the question is not one
     *                                                  of its QUIZ questions
     * @throws mn.uziy.backend.common.BadRequestException the answer is not one of the question's options
     */
    QuizCheckResult check(long campaignId, long questionId, String answer);
}
