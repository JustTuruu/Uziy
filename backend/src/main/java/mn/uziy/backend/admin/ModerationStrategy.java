package mn.uziy.backend.admin;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;

/**
 * Pattern: Strategy — one implementation per admin moderation outcome. A new outcome is a new
 * {@code @Component}; {@link CampaignModerationServiceImpl} needs no change (OCP).
 */
public interface ModerationStrategy {

    /** The status this strategy moves a PENDING campaign to. */
    CampaignStatus target();

    /** Applies the decision to the campaign. */
    default void apply(CampaignEntity campaign, OffsetDateTime now) {
        campaign.setStatus(target());
        campaign.setUpdatedAt(now);
    }
}
