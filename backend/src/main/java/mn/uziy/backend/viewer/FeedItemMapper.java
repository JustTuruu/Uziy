package mn.uziy.backend.viewer;

import mn.uziy.backend.domain.CampaignEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — campaign entity (+ its company's display name) to {@link FeedItemDto}. */
@Component
public class FeedItemMapper {

    public FeedItemDto toDto(CampaignEntity c, String companyName) {
        return new FeedItemDto(
                c.getId(),
                c.getTitle(),
                c.getVideoUrl(),
                c.getThumbnailUrl(),
                c.getDurationSeconds(),
                c.hasVideo(),
                c.getRewardPerUser(),
                companyName);
    }
}
