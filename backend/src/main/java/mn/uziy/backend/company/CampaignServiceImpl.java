package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyMessages.AMOUNT_TOO_LARGE_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.DURATION_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.NO_QUESTIONS_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.TOO_MANY_VIEWERS_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.TRANSITION_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.WHOLE_TUGRIK_MESSAGE;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PlatformSettings;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import mn.uziy.backend.domain.PlatformSettingsRepository;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.pricing.CampaignPricing;
import mn.uziy.backend.pricing.PricingError;
import mn.uziy.backend.pricing.PricingMode;
import mn.uziy.backend.pricing.PricingResult;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CampaignServiceImpl implements CampaignService {

    /**
     * 10^15 ₮ — far beyond any real budget, and below 2^53 so every
     * whole-tögrög value survives the DOUBLE PRECISION money columns.
     */
    public static final long MAX_AMOUNT = 1_000_000_000_000_000L;

    static final int MIN_DURATION_SECONDS = 5;
    static final int MAX_DURATION_SECONDS = 180;

    /** The only status changes a company may make on its own campaign. */
    public static final Map<CampaignStatus, Set<CampaignStatus>> COMPANY_TRANSITIONS = Map.of(
            CampaignStatus.ACTIVE, Set.of(CampaignStatus.PAUSED, CampaignStatus.COMPLETED),
            CampaignStatus.PAUSED, Set.of(CampaignStatus.ACTIVE, CampaignStatus.COMPLETED));

    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;
    private final PlatformSettingsRepository platformSettings;

    public CampaignServiceImpl(CampaignRepository campaigns,
                               SurveyQuestionRepository questions,
                               PlatformSettingsRepository platformSettings) {
        this.campaigns = campaigns;
        this.questions = questions;
        this.platformSettings = platformSettings;
    }

    @Override
    public List<CampaignDto> list(long companyId) {
        return campaigns.findAllByCompanyIdOrderByCreatedAtDesc(companyId).stream()
                .map(CampaignDto::of)
                .toList();
    }

    @Override
    public CampaignDto get(long companyId, long campaignId) {
        return CampaignDto.of(OwnedCampaigns.owned(campaigns, companyId, campaignId));
    }

    @Override
    @Transactional
    public CampaignDto create(long companyId, CreateCampaignReq req) {
        PricingMode mode = pricingMode(req);
        validateShape(req);
        PricingResult pricing = price(req, mode);

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
        // Only P = C × N is charged; any remainder of B is not.
        entity.setTotalBudget((double) pricing.payable());
        entity.setRemainingBudget((double) pricing.payable());
        entity.setCostPerView((double) pricing.costPerViewer());
        entity.setRewardPerUser((double) pricing.rewardPerViewer());
        entity.setTargetViewers((int) pricing.targetViewers());
        entity.setCommissionPercent(pricing.commissionPercent());
        entity.setStatus(CampaignStatus.AWAITING_PAYMENT);

        CampaignEntity c = campaigns.save(entity);
        saveQuestions(c.getId(), req.questions());
        return CampaignDto.of(c);
    }

    @Override
    @Transactional
    public CampaignDto setStatus(long companyId, long campaignId, CampaignStatus status) {
        CampaignEntity c = OwnedCampaigns.owned(campaigns, companyId, campaignId);
        CampaignStatus from = c.getStatus();
        if (!COMPANY_TRANSITIONS.getOrDefault(from, Set.of()).contains(status)) {
            throw new ConflictException(TRANSITION_MESSAGE);
        }

        OffsetDateTime at = CompanyClock.now();
        if (campaigns.tryTransition(campaignId, from, status, at) == 0) {
            throw new ConflictException(TRANSITION_MESSAGE);
        }

        // Detached (clearAutomatically) — response only, not written back.
        c.setStatus(status);
        c.setUpdatedAt(at);
        return CampaignDto.of(c);
    }

    // --- create() steps ------------------------------------------------------

    /** Exactly one of targetViewers / rewardPerUser drives the pricing. */
    private static PricingMode pricingMode(CreateCampaignReq req) {
        if (req.targetViewers() != null && req.rewardPerUser() == null) {
            return PricingMode.VIEWERS;
        }
        if (req.targetViewers() == null && req.rewardPerUser() != null) {
            return PricingMode.REWARD;
        }
        throw new BadRequestException(EXACTLY_ONE_DRIVER_MESSAGE);
    }

    private static void validateShape(CreateCampaignReq req) {
        if (req.hasVideo()) {
            int d = req.durationSeconds();
            if (d < MIN_DURATION_SECONDS || d > MAX_DURATION_SECONDS) {
                throw new BadRequestException(DURATION_MESSAGE);
            }
        } else if (req.questions().isEmpty()) {
            throw new BadRequestException(NO_QUESTIONS_MESSAGE);
        }
    }

    private PricingResult price(CreateCampaignReq req, PricingMode mode) {
        PlatformSettingsEntity settings = PlatformSettings.current(platformSettings);
        long minReward = settings.getMinRewardPerViewer();
        Integer viewers = req.targetViewers();
        PricingResult pricing = CampaignPricing.compute(
                mode,
                wholeTugrik(req.totalBudget()),
                settings.getCommissionPercent(),
                minReward,
                viewers == null ? null : viewers.longValue(),
                mode == PricingMode.REWARD ? Long.valueOf(wholeTugrik(req.rewardPerUser())) : null);
        PricingError error = pricing.error();
        if (error != null) {
            throw new BadRequestException(error.message(minReward));
        }
        if (pricing.targetViewers() > Integer.MAX_VALUE) {
            throw new BadRequestException(TOO_MANY_VIEWERS_MESSAGE);
        }
        return pricing;
    }

    private void saveQuestions(long campaignId, List<CreateCampaignReq.NewQuestion> newQuestions) {
        int position = 1;
        for (CreateCampaignReq.NewQuestion q : newQuestions) {
            SurveyQuestionEntity e = new SurveyQuestionEntity();
            e.setCampaignId(campaignId);
            e.setPosition(position++);
            e.setPrompt(q.prompt());
            e.setQType(q.type());
            e.setOptionsJson(optionsJson(q.options()));
            e.setRequired(q.required());
            questions.save(e);
        }
    }

    private static String optionsJson(List<String> options) {
        return options.stream()
                .map(o -> "\"" + o.replace("\"", "\\\"") + "\"")
                .collect(Collectors.joining(", ", "[", "]"));
    }

    /**
     * JSON number → whole ₮. null → 0 (so the pricing function reports
     * the "enter a value" message). Fractions and absurd values → 400.
     */
    private static long wholeTugrik(@Nullable Double value) {
        if (value == null) {
            return 0;
        }
        if (!Double.isFinite(value) || value % 1.0 != 0.0) {
            throw new BadRequestException(WHOLE_TUGRIK_MESSAGE);
        }
        if (value > MAX_AMOUNT) {
            throw new BadRequestException(AMOUNT_TOO_LARGE_MESSAGE);
        }
        return value.longValue();
    }
}
