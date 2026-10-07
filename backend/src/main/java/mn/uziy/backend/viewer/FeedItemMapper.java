package mn.uziy.backend.viewer;

import mn.uziy.backend.domain.CampaignEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — campaign entity (+ its company's display name) to {@link FeedItemDto}. */
@Component
public class FeedItemMapper {

    /** Same card for a guest, but without the video URL: watching requires an account. */
    public FeedItemDto toGuestDto(CampaignEntity c, String companyName) {
        FeedItemDto full = toDto(c, companyName);
        return new FeedItemDto(full.id(), full.title(), "", full.thumbnailUrl(),
                full.durationSeconds(), full.hasVideo(), full.rewardPerUser(), full.companyName());
    }

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
