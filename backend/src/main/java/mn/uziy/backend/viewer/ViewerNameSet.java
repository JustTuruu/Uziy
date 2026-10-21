package mn.uziy.backend.viewer;

import mn.uziy.backend.common.event.DomainEvent;

/** An older account was given its name (audit trail: the name takes part in the payout check). */
public record ViewerNameSet(long viewerId) implements DomainEvent {
}
