package mn.uziy.backend.payout;

import mn.uziy.backend.common.event.DomainEvent;

/** Raised when a viewer reserves balance for a new PENDING payout. */
public record PayoutRequested(long payoutId, long userId, double amount) implements DomainEvent {
}
