package mn.uziy.backend.admin;

import mn.uziy.backend.company.CampaignDto;
import org.jspecify.annotations.Nullable;

/**
 * Extended campaign shape returned by /admin/campaigns/{id} — carries the
 * completion counter and owning company name that the list DTO leaves off.
 */
public record CampaignDetailDto(
        CampaignDto campaign,
        long companyId,
        @Nullable String companyName,
        long completedViews,
        double spentBudget) {
}
