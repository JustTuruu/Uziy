package mn.uziy.backend.common.event;

/** Pattern: Observer — port services use to announce a {@link DomainEvent}. */
public interface DomainEventPublisher {

    void publish(DomainEvent event);
}
