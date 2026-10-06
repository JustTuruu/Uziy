package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyMessages.AMOUNT_TOO_LARGE_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.DURATION_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.EXACTLY_ONE_DRIVER_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.NO_QUESTIONS_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.TOO_MANY_VIEWERS_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.TRANSITION_MESSAGE;
import static mn.uziy.backend.company.CompanyMessages.WHOLE_TUGRIK_MESSAGE;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.CampaignActor;
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

/** Pattern: State — status changes are decided by {@code CampaignStatus.canTransitionTo}. */
@Service
public class CampaignServiceImpl implements CampaignService {

    /**
     * 10^15 ₮ — far beyond any real budget, and below 2^53 so every
     * whole-tögrög value survives the DOUBLE PRECISION money columns.
     */
    public static final long MAX_AMOUNT = 1_000_000_000_000_000L;

    static final int MIN_DURATION_SECONDS = 5;
    static final int MAX_DURATION_SECONDS = 180;

    private final CampaignRepository campaigns;
    private final SurveyQuestionRepository questions;
    private final PlatformSettingsRepository platformSettings;
    private final CampaignFactory factory;
    private final CampaignMapper mapper;
    private final DomainEventPublisher events;
    private final Clock clock;

    public CampaignServiceImpl(CampaignRepository campaigns,
                               SurveyQuestionRepository questions,
                               PlatformSettingsRepository platformSettings,
                               CampaignFactory factory,
                               CampaignMapper mapper,
                               DomainEventPublisher events,
                               Clock clock) {
        this.campaigns = campaigns;
        this.questions = questions;
        this.platformSettings = platformSettings;
        this.factory = factory;
        this.mapper = mapper;
        this.events = events;
        this.clock = clock;
    }

    @Override
    public List<CampaignDto> list(long companyId) {
        return campaigns.findAllByCompanyIdOrderByCreatedAtDesc(companyId).stream()
                .map(mapper::toDto)
                .toList();
    }

    @Override
    public CampaignDto get(long companyId, long campaignId) {
        return mapper.toDto(OwnedCampaigns.owned(campaigns, companyId, campaignId));
    }

    @Override
    @Transactional
    public CampaignDto create(long companyId, CreateCampaignReq req) {
        PricingMode mode = pricingMode(req);
        validateShape(req);
        PricingResult pricing = price(req, mode);

        CampaignEntity c = campaigns.save(factory.newCampaign(companyId, req, pricing));
        saveQuestions(c.getId(), req.questions());
        events.publish(new CampaignCreated(c.getId(), companyId));
        return mapper.toDto(c);
    }

    @Override
    @Transactional
    public CampaignDto setStatus(long companyId, long campaignId, CampaignStatus status) {
        CampaignEntity c = OwnedCampaigns.owned(campaigns, companyId, campaignId);
        CampaignStatus from = c.getStatus();
        if (!from.canTransitionTo(status, CampaignActor.COMPANY)) {
            throw new ConflictException(TRANSITION_MESSAGE);
        }

        OffsetDateTime at = OffsetDateTime.now(clock).truncatedTo(ChronoUnit.MICROS);
        if (campaigns.tryTransition(campaignId, from, status, at) == 0) {
            throw new ConflictException(TRANSITION_MESSAGE);
        }

        // Detached (clearAutomatically) — response only, not written back.
        c.setStatus(status);
        c.setUpdatedAt(at);
        events.publish(new CampaignStatusChanged(campaignId, from, status, CampaignActor.COMPANY));
        return mapper.toDto(c);
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
        for (SurveyQuestionEntity e : factory.newQuestions(campaignId, newQuestions)) {
            questions.save(e);
        }
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
