package mn.uziy.backend.admin;

import mn.uziy.backend.domain.CampaignStatus;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — approval: PENDING → ACTIVE. */
@Component
public class ApproveCampaignStrategy implements ModerationStrategy {

    @Override
    public CampaignStatus target() {
        return CampaignStatus.ACTIVE;
    }
}
