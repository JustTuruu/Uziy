package mn.uziy.backend.account;

import mn.uziy.backend.common.event.DomainEvent;

/** A viewer deleted their account. Carries the row id only — the personal data is gone and must not be logged. */
public record ViewerDeleted(long viewerId) implements DomainEvent {
}
