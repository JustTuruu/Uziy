package mn.uziy.backend.admin;

import mn.uziy.backend.common.event.DomainEvent;

/** Pattern: Observer — an admin opened a company account (ids only: the audit log must not carry the phone). */
public record CompanyCreated(long companyId, long adminId) implements DomainEvent {
}
