package mn.uziy.backend.admin;

import java.time.OffsetDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.company.CampaignDto;
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
    private static final Set<CampaignStatus> MODERATION_DECISIONS =
            Set.of(CampaignStatus.ACTIVE, CampaignStatus.REJECTED);

    private final CampaignRepository campaigns;
    private final UserRepository users;
    private final ViewHistoryRepository history;

    public CampaignModerationServiceImpl(CampaignRepository campaigns, UserRepository users,
                                         ViewHistoryRepository history) {
        this.campaigns = campaigns;
        this.users = users;
        this.history = history;
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
        return list.stream().map(CampaignDto::of).toList();
    }

    @Override
    public CampaignDetailDto get(long campaignId) {
        CampaignEntity c = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException(NOT_FOUND_MESSAGE));
        String companyName = users.findById(c.getCompanyId()).map(UserEntity::getCompanyName).orElse(null);
        return new CampaignDetailDto(
                CampaignDto.of(c),
                c.getCompanyId(),
                companyName,
                history.countByCampaignId(c.getId()),
                c.getTotalBudget() - c.getRemainingBudget());
    }

    @Override
    @Transactional
    public CampaignDto moderate(long campaignId, CampaignStatus decision) {
        if (!MODERATION_DECISIONS.contains(decision)) {
            throw new BadRequestException("Only ACTIVE or REJECTED allowed for moderation");
        }
        CampaignEntity c = campaigns.findById(campaignId)
                .orElseThrow(() -> new NotFoundException(NOT_FOUND_MESSAGE));
        if (c.getStatus() == CampaignStatus.AWAITING_PAYMENT) {
            throw new ConflictException(UNPAID_MESSAGE);
        }
        if (c.getStatus() != CampaignStatus.PENDING) {
            throw new ConflictException("Already moderated");
        }
        c.setStatus(decision);
        c.setUpdatedAt(OffsetDateTime.now());
        return CampaignDto.of(campaigns.save(c));
    }
}
