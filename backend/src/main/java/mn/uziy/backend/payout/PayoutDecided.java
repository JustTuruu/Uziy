package mn.uziy.backend.payout;

import mn.uziy.backend.common.event.DomainEvent;
import mn.uziy.backend.domain.PayoutStatus;

/** Raised when an admin approves or rejects a payout. */
public record PayoutDecided(long payoutId, long userId, PayoutStatus decision, long adminId)
        implements DomainEvent {
}
