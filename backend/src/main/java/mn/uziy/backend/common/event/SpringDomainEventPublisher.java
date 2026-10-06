package mn.uziy.backend.common.event;

import java.util.Objects;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * Pattern: Observer — adapter over Spring's {@link ApplicationEventPublisher}.
 * Delivery is synchronous, so listeners run inside the publisher's transaction.
 */
@Component
public class SpringDomainEventPublisher implements DomainEventPublisher {

    private final ApplicationEventPublisher delegate;

    public SpringDomainEventPublisher(ApplicationEventPublisher delegate) {
        this.delegate = delegate;
    }

    @Override
    public void publish(DomainEvent event) {
        Objects.requireNonNull(event, "event");
        delegate.publishEvent(event);
    }
}
