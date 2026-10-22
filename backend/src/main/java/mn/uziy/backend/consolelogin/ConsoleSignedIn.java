package mn.uziy.backend.consolelogin;

import mn.uziy.backend.common.event.DomainEvent;
import mn.uziy.backend.domain.Role;

/**
 * Pattern: Observer — an admin or a company received a token: after the SMS step ({@code newDevice}) or from a
 * remembered browser. Ids only.
 */
public record ConsoleSignedIn(long userId, Role role, boolean newDevice) implements DomainEvent {
}
