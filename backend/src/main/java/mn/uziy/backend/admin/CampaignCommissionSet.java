package mn.uziy.backend.admin;

import mn.uziy.backend.common.event.DomainEvent;
import org.jspecify.annotations.Nullable;

/** Raised when an admin approved a campaign at its own commission (audit trail of the money split). */
public record CampaignCommissionSet(long campaignId, @Nullable Integer fromPercent, int toPercent,
                                    long rewardPerViewer) implements DomainEvent {
}
