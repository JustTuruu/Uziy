package mn.uziy.backend.common.event;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/** Pattern: Observer — concrete observer writing one audit line per domain event. */
@Component
public class AuditLogListener {

    private static final Logger LOG = LoggerFactory.getLogger(AuditLogListener.class);

    @EventListener
    public void onEvent(DomainEvent event) {
        LOG.info("audit event={} {}", event.getClass().getSimpleName(), event);
    }
}
