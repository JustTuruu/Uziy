package mn.uziy.backend.adminlogin;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — an admin finished both login steps (password + phone) and received a token. */
public record AdminSignedIn(long adminId) implements DomainEvent {
}
