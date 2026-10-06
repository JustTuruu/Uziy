package mn.uziy.backend.company;

import mn.uziy.backend.common.event.DomainEvent;

/** Raised when a company has created a campaign (it starts in AWAITING_PAYMENT). */
public record CampaignCreated(long campaignId, long companyId) implements DomainEvent {
}
