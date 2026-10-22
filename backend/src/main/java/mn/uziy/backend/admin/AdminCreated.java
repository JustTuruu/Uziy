package mn.uziy.backend.admin;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — an admin opened another admin's account (ids only: the audit log must not carry the phone). */
public record AdminCreated(long newAdminId, long adminId) implements DomainEvent {
}
