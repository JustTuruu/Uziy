package mn.uziy.backend.passwordreset;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — a viewer set a new password after proving the phone. The account id only. */
public record PasswordReset(long userId) implements DomainEvent {
}
