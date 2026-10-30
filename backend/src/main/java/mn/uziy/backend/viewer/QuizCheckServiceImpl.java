package mn.uziy.backend.viewer;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.company.QuizQuestion;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class QuizCheckServiceImpl implements QuizCheckService {

    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;

    public QuizCheckServiceImpl(CampaignRepository campaigns, SurveyQuestionRepository questions) {
        this.campaigns = campaigns;
        this.questions = questions;
    }

    @Override
    @Transactional(readOnly = true)
    public QuizCheckResult check(long campaignId, long questionId, String answer) {
        // Same visibility as the survey itself: only a running campaign's questions exist for viewers.
        campaigns.findById(campaignId)
                .filter(c -> c.getStatus() == CampaignStatus.ACTIVE)
                .orElseThrow(() -> new NotFoundException(Messages.OFFER_NOT_FOUND));
        SurveyQuestionEntity q = questions.findById(questionId)
                .filter(found -> found.getCampaignId() == campaignId && QuizQuestion.isQuiz(found.getQType()))
                .orElseThrow(() -> new NotFoundException(AnswerValidator.UNKNOWN_QUESTION));
        if (!QuestionMapper.parseOptions(q.getOptionsJson()).contains(answer)) {
            throw new BadRequestException(AnswerValidator.BAD_ANSWER);
        }
        return new QuizCheckResult(AnswerValidator.isCorrect(q, answer));
    }
}
