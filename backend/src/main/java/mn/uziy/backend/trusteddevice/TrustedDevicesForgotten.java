package mn.uziy.backend.trusteddevice;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — an admin made every browser of {@code userId} a stranger again (ids and a count only). */
public record TrustedDevicesForgotten(long userId, long adminId, int forgotten) implements DomainEvent {
}
