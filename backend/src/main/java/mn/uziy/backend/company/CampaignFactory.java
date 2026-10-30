package mn.uziy.backend.company;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.pricing.PricingResult;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

/** Pattern: Factory — builds new campaign, question and payment entities from validated input. */
@Component
public class CampaignFactory {

    private static final JsonMapper JSON = JsonMapper.builder().build();

    /** A new campaign in AWAITING_PAYMENT; only P = C × N is charged, any remainder of B is not. */
    public CampaignEntity newCampaign(long companyId, CreateCampaignReq req, PricingResult pricing) {
        CampaignEntity entity = new CampaignEntity();
        entity.setCompanyId(companyId);
        entity.setTitle(req.title());
        entity.setVideoUrl(req.hasVideo() ? req.videoUrl() : "");
        entity.setDurationSeconds(req.hasVideo() ? req.durationSeconds() : 0);
        entity.setHasVideo(req.hasVideo());
        entity.setTargetGender(req.targetGender());
        entity.setMinAge(req.minAge());
        entity.setMaxAge(req.maxAge());
        entity.setTargetCity(req.targetCity());
        entity.setTotalBudget((double) pricing.payable());
        entity.setRemainingBudget((double) pricing.payable());
        entity.setCostPerView((double) pricing.costPerViewer());
        entity.setRewardPerUser((double) pricing.rewardPerViewer());
        entity.setTargetViewers((int) pricing.targetViewers());
        entity.setCommissionPercent(pricing.commissionPercent());
        entity.setStatus(CampaignStatus.AWAITING_PAYMENT);
        return entity;
    }

    /** The survey questions of a campaign, positions numbered from 1 in request order. */
    public List<SurveyQuestionEntity> newQuestions(long campaignId, List<CreateCampaignReq.NewQuestion> source) {
        List<SurveyQuestionEntity> result = new ArrayList<>();
        int position = 1;
        for (CreateCampaignReq.NewQuestion q : source) {
            SurveyQuestionEntity e = new SurveyQuestionEntity();
            e.setCampaignId(campaignId);
            e.setPosition(position++);
            e.setPrompt(q.prompt());
            e.setQType(q.type());
            e.setOptionsJson(optionsJson(optionsOf(q)));
            boolean quiz = QuizQuestion.isQuiz(q.type());
            // A quiz is the proof of watching, so it can never be skipped.
            e.setRequired(quiz || q.required());
            e.setCorrectAnswer(quiz ? q.correctAnswer() : null);
            result.add(e);
        }
        return result;
    }

    /** A PAID payment row for the campaign's full budget. */
    public CampaignPaymentEntity newPaidPayment(CampaignEntity campaign, PaymentProvider provider,
                                                String reference, OffsetDateTime paidAt) {
        CampaignPaymentEntity entity = new CampaignPaymentEntity();
        entity.setCampaignId(campaign.getId());
        entity.setCompanyId(campaign.getCompanyId());
        entity.setAmount(campaign.getTotalBudget());
        entity.setProvider(provider);
        entity.setStatus(PaymentStatus.PAID);
        entity.setReference(reference);
        entity.setCreatedAt(paidAt);
        entity.setPaidAt(paidAt);
        return entity;
    }

    /** A rating question always offers the fixed scale, whatever the request listed. */
    private static List<String> optionsOf(CreateCampaignReq.NewQuestion q) {
        return RatingScale.TYPE.equals(q.type()) ? RatingScale.LABELS : q.options();
    }

    /**
     * A real JSON encoder, never string gluing: escaping only quotes let a backslash, a line break or a tab
     * that a company typed into an option produce invalid JSON, and the insert failed with a 500.
     */
    private static String optionsJson(List<String> options) {
        return JSON.writeValueAsString(options);
    }
}
