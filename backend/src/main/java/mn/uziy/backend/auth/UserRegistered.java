package mn.uziy.backend.auth;

import mn.uziy.backend.common.event.DomainEvent;
import mn.uziy.backend.domain.Role;

/** Pattern: Observer — raised after a new account is saved. */
public record UserRegistered(long userId, Role role) implements DomainEvent {
}
