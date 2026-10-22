package mn.uziy.backend.handoff;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — an admin's handoff code was spent and the admin panel got a session (ids only). */
public record SessionHandedOff(long adminId) implements DomainEvent {
}
