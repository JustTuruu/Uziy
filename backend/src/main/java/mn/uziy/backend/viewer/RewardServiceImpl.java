package mn.uziy.backend.viewer;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.SurveyResponseEntity;
import mn.uziy.backend.domain.SurveyResponseRepository;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryEntity;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service("rewardServiceImpl")
public class RewardServiceImpl implements RewardService {

    static final String NOT_AVAILABLE = Messages.OFFER_NOT_FOUND;
    static final String ALREADY_REWARDED = "Та энэ урамшууллыг аль хэдийн авсан байна";
    static final String BUDGET_SPENT = "Уучлаарай, энэ урамшууллын төсөв дууссан байна";

    private final UserRepository users;
    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;
    private final ViewHistoryRepository history;
    private final SurveyResponseRepository responses;

    private final DomainEventPublisher events;
    private final AnswerValidator answerValidator;

    public RewardServiceImpl(UserRepository users, CampaignRepository campaigns,
                             SurveyQuestionRepository questions, ViewHistoryRepository history,
                             SurveyResponseRepository responses, DomainEventPublisher events,
                             AnswerValidator answerValidator) {
        this.answerValidator = answerValidator;
        this.events = events;
        this.users = users;
        this.campaigns = campaigns;
        this.questions = questions;
        this.history = history;
        this.responses = responses;
    }

    @Override
    @Transactional(isolation = Isolation.SERIALIZABLE)
    public RewardResult submitSurvey(long userId, long campaignId, List<SubmitSurveyReq.Answer> answers) {
        if (history.existsByUserIdAndCampaignId(userId, campaignId)) {
            throw new ConflictException(ALREADY_REWARDED);
        }

        CampaignEntity campaign = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException(NOT_AVAILABLE));

        UserEntity viewer = users.findById(userId).orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
        if (!CampaignTargeting.matches(campaign, viewer)) {
            // Same answer as for a campaign that does not exist: the audience rule is not for viewers to probe.
            throw new NotFoundException(NOT_AVAILABLE);
        }
        List<SurveyQuestionEntity> campaignQuestions = questions.findAllByCampaignIdOrderByPosition(campaign.getId());
        answerValidator.validate(campaignQuestions, answers);

        if (campaigns.tryDecrementBudget(campaign.getId()) == 0) {
            throw new ConflictException(BUDGET_SPENT);
        }

        ViewHistoryEntity newView = new ViewHistoryEntity();
        newView.setUserId(userId);
        newView.setCampaignId(campaign.getId());
        newView.setRewardPaid(campaign.getRewardPerUser());
        ViewHistoryEntity view = history.save(newView);

        recordAnswers(view.getId(), campaignQuestions, answers);

        // Atomic credit: never a read-modify-write of the balance.
        users.addBalance(userId, campaign.getRewardPerUser());
        double newBalance = users.currentBalance(userId).orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));

        events.publish(new RewardGranted(userId, campaign.getId(), campaign.getRewardPerUser()));
        return new RewardResult(campaign.getRewardPerUser(), newBalance);
    }

    /** Stores the non-empty answers; the validator already vouched for them. */
    private void recordAnswers(long viewId, List<SurveyQuestionEntity> campaignQuestions,
                               List<SubmitSurveyReq.Answer> answers) {
        Set<Long> validQuestionIds = campaignQuestions.stream()
                .map(SurveyQuestionEntity::getId)
                .collect(Collectors.toSet());
        for (SubmitSurveyReq.Answer a : answers) {
            if (!validQuestionIds.contains(a.questionId()) || a.answerJson() == null || a.answerJson().isBlank()) {
                continue;
            }
            SurveyResponseEntity r = new SurveyResponseEntity();
            r.setViewId(viewId);
            r.setQuestionId(a.questionId());
            r.setAnswerJson(a.answerJson());
            responses.save(r);
        }
    }
}
