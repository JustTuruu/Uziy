package mn.uziy.backend.privacy;

import mn.uziy.backend.common.event.DomainEvent;

/** A viewer said yes or no to anonymous statistics (audited by AuditLogListener). */
public record StatisticsConsentChanged(long viewerId, StatisticsConsentStatus status, String version)
        implements DomainEvent {
}
