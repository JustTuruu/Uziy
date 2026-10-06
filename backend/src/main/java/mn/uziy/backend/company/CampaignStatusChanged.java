package mn.uziy.backend.company;

import mn.uziy.backend.common.event.DomainEvent;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignStatus;

/** Raised after a campaign moved from one lifecycle status to another. */
public record CampaignStatusChanged(long campaignId, CampaignStatus from, CampaignStatus to,
                                    CampaignActor actor) implements DomainEvent {
}
