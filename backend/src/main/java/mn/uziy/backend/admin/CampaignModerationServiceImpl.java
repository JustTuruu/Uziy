package mn.uziy.backend.admin;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.company.CampaignStatusChanged;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CampaignModerationServiceImpl implements CampaignModerationService {

    public static final String UNPAID_MESSAGE = "Төлбөр нь төлөгдөөгүй аяныг хянах боломжгүй";
    private static final String NOT_FOUND_MESSAGE = "Campaign not found";
    private static final String INVALID_DECISION_MESSAGE = "Only ACTIVE or REJECTED allowed for moderation";
    private static final String ALREADY_MODERATED_MESSAGE = "Already moderated";

    private final CampaignRepository campaigns;
    private final UserRepository users;
    private final ViewHistoryRepository history;
    private final AdminCampaignMapper mapper;
    private final ModerationStrategyRegistry strategies;
    private final DomainEventPublisher events;
    private final Clock clock;

    public CampaignModerationServiceImpl(CampaignRepository campaigns, UserRepository users,
                                         ViewHistoryRepository history, AdminCampaignMapper mapper,
                                         ModerationStrategyRegistry strategies, DomainEventPublisher events,
                                         Clock clock) {
        this.campaigns = campaigns;
        this.users = users;
        this.history = history;
        this.mapper = mapper;
        this.strategies = strategies;
        this.events = events;
        this.clock = clock;
    }

    @Override
    public List<CampaignDto> list(@Nullable CampaignStatus status, @Nullable Long companyId) {
        List<CampaignEntity> list;
        if (companyId != null) {
            list = campaigns.findAllByCompanyIdOrderByCreatedAtDesc(companyId).stream()
                    .filter(c -> status == null || c.getStatus() == status)
                    .toList();
        } else if (status != null) {
            list = campaigns.findAllByStatusOrderByCreatedAtDesc(status);
        } else {
            list = campaigns.findAll().stream()
                    .sorted(Comparator.comparing(CampaignEntity::getCreatedAt).reversed())
                    .toList();
        }
        return list.stream().map(mapper::toDto).toList();
    }

    @Override
    public CampaignDetailDto get(long campaignId) {
        CampaignEntity c = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException(NOT_FOUND_MESSAGE));
        String companyName = users.findById(c.getCompanyId()).map(UserEntity::getCompanyName).orElse(null);
        return mapper.toDetail(c, companyName, history.countByCampaignId(c.getId()));
    }

    @Override
    @Transactional
    public CampaignDto moderate(long campaignId, CampaignStatus decision) {
        ModerationStrategy strategy = strategies.find(decision)
                .orElseThrow(() -> new BadRequestException(INVALID_DECISION_MESSAGE));
        CampaignEntity c = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException(NOT_FOUND_MESSAGE));
        CampaignStatus from = c.getStatus();
        if (from == CampaignStatus.AWAITING_PAYMENT) {
            throw new ConflictException(UNPAID_MESSAGE);
        }
        if (!from.canTransitionTo(decision, CampaignActor.ADMIN)) {
            throw new ConflictException(ALREADY_MODERATED_MESSAGE);
        }
        strategy.apply(c, OffsetDateTime.now(clock));
        CampaignEntity saved = campaigns.save(c);
        events.publish(new CampaignStatusChanged(saved.getId(), from, decision, CampaignActor.ADMIN));
        return mapper.toDto(saved);
    }
}
