package mn.uziy.backend.viewer;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import mn.uziy.backend.common.ConflictException;
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

@Service
public class RewardServiceImpl implements RewardService {

    private static final String EMPTY_JSON_STRING = "\"\"";

    private final UserRepository users;
    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;
    private final ViewHistoryRepository history;
    private final SurveyResponseRepository responses;

    private final DomainEventPublisher events;

    public RewardServiceImpl(UserRepository users, CampaignRepository campaigns,
                             SurveyQuestionRepository questions, ViewHistoryRepository history,
                             SurveyResponseRepository responses, DomainEventPublisher events) {
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
            throw new ConflictException("Already rewarded for this campaign");
        }

        CampaignEntity campaign = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException("Campaign not found"));

        if (campaigns.tryDecrementBudget(campaign.getId()) == 0) {
            throw new ConflictException("Campaign no longer available");
        }

        ViewHistoryEntity newView = new ViewHistoryEntity();
        newView.setUserId(userId);
        newView.setCampaignId(campaign.getId());
        newView.setRewardPaid(campaign.getRewardPerUser());
        ViewHistoryEntity view = history.save(newView);

        recordAnswers(view.getId(), campaign.getId(), answers);

        UserEntity user = users.findById(userId).orElseThrow();
        user.setBalance(user.getBalance() + campaign.getRewardPerUser());
        users.save(user);

        events.publish(new RewardGranted(userId, campaign.getId(), campaign.getRewardPerUser()));
        return new RewardResult(campaign.getRewardPerUser(), user.getBalance());
    }

    /** Answers to questions that don't belong to this campaign are ignored. */
    private void recordAnswers(long viewId, long campaignId, List<SubmitSurveyReq.Answer> answers) {
        Set<Long> validQuestionIds = questions.findAllByCampaignIdOrderByPosition(campaignId).stream()
                .map(SurveyQuestionEntity::getId)
                .collect(Collectors.toSet());
        for (SubmitSurveyReq.Answer a : answers) {
            if (!validQuestionIds.contains(a.questionId())) {
                continue;
            }
            SurveyResponseEntity r = new SurveyResponseEntity();
            r.setViewId(viewId);
            r.setQuestionId(a.questionId());
            r.setAnswerJson(a.answerJson().isBlank() ? EMPTY_JSON_STRING : a.answerJson());
            responses.save(r);
        }
    }
}
