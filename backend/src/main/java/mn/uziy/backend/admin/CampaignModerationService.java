package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.domain.CampaignStatus;
import org.jspecify.annotations.Nullable;

/** The admin's campaign oversight: browse, inspect, approve / reject. */
public interface CampaignModerationService {
    List<CampaignDto> list(@Nullable CampaignStatus status, @Nullable Long companyId);

    CampaignDetailDto get(long campaignId);

    /** Only paid campaigns (PENDING) can be moderated, to ACTIVE or REJECTED; keeps the campaign's commission. */
    default CampaignDto moderate(long campaignId, CampaignStatus decision) {
        return moderate(campaignId, decision, null);
    }

    /**
     * As above; approving with a {@code commissionPercent} first re-splits what the company paid at that
     * percentage ({@link CampaignCommission}). A percentage with any other decision is a 400.
     */
    CampaignDto moderate(long campaignId, CampaignStatus decision, @Nullable Integer commissionPercent);
}
