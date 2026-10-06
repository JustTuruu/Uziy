package mn.uziy.backend.common.event;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

@ExtendWith(MockitoExtension.class)
class SpringDomainEventPublisherTest {

    private record Ping(long id) implements DomainEvent {
    }

    @Mock
    ApplicationEventPublisher delegate;

    @Test
    void publishDelegatesTheSameEventInstance() {
        Ping event = new Ping(1);
        new SpringDomainEventPublisher(delegate).publish(event);
        verify(delegate).publishEvent((Object) event);
    }

    @Test
    void publishRejectsNull() {
        assertThatThrownBy(() -> new SpringDomainEventPublisher(delegate).publish(null))
                .isInstanceOf(NullPointerException.class);
        verifyNoInteractions(delegate);
    }
}
