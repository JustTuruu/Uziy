package mn.uziy.backend.admin;

import mn.uziy.backend.domain.CampaignStatus;
import org.springframework.stereotype.Component;

/** Pattern: Strategy — rejection: PENDING → REJECTED. */
@Component
public class RejectCampaignStrategy implements ModerationStrategy {

    @Override
    public CampaignStatus target() {
        return CampaignStatus.REJECTED;
    }
}
