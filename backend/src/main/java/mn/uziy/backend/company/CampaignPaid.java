package mn.uziy.backend.company;

import mn.uziy.backend.common.event.DomainEvent;

/** Raised when a campaign has been paid for. */
public record CampaignPaid(long campaignId, long companyId, double amount, String reference)
        implements DomainEvent {
}
