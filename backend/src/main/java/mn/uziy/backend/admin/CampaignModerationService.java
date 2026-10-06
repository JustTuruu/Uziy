package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.domain.CampaignStatus;
import org.jspecify.annotations.Nullable;

/** The admin's campaign oversight: browse, inspect, approve / reject. */
public interface CampaignModerationService {
    List<CampaignDto> list(@Nullable CampaignStatus status, @Nullable Long companyId);

    CampaignDetailDto get(long campaignId);

    /** Only paid campaigns (PENDING) can be moderated, to ACTIVE or REJECTED. */
    CampaignDto moderate(long campaignId, CampaignStatus decision);
}
