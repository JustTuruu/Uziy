package mn.uziy.backend.viewer;

import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.ViewHistoryEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — a view-history row (+ its campaign and company name) to {@link ViewHistoryItemDto}. */
@Component
public class ViewHistoryMapper {

    public ViewHistoryItemDto toDto(ViewHistoryEntity view, CampaignEntity campaign, String companyName) {
        return new ViewHistoryItemDto(
                view.getCampaignId(),
                campaign.getTitle(),
                companyName,
                view.getRewardPaid(),
                view.getWatchedAt());
    }
}
