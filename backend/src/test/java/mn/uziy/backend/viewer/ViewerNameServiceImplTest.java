package mn.uziy.backend.viewer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class ViewerNameServiceImplTest {

    private static final long VIEWER = 42L;

    private final UserRepository users = mock(UserRepository.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final ViewerNameServiceImpl service = new ViewerNameServiceImpl(users, new MeMapper(), events);

    private static UserEntity viewer(String lastName, String firstName) {
        UserEntity u = new UserEntity();
        u.setId(VIEWER);
        u.setPhoneNumber("99112233");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setLastName(lastName);
        u.setFirstName(firstName);
        return u;
    }

    @Test
    void anAccountWithoutANameGetsItTrimmedAndTheEventIsRaised() {
        when(users.trySetNameOnce(VIEWER, Role.VIEWER, "Бат", "Сараа")).thenReturn(1);
        when(users.findById(VIEWER)).thenReturn(Optional.of(viewer("Бат", "Сараа")));

        Me me = service.setNameOnce(VIEWER, "  Бат ", " Сараа  ");

        assertThat(me.lastName()).isEqualTo("Бат");
        assertThat(me.firstName()).isEqualTo("Сараа");
        verify(users).trySetNameOnce(VIEWER, Role.VIEWER, "Бат", "Сараа");
        verify(events).publish(new ViewerNameSet(VIEWER));
    }

    @Test
    void aNameIsNeverOverwritten() {
        when(users.trySetNameOnce(VIEWER, Role.VIEWER, "Өөр", "Хүн")).thenReturn(0);
        when(users.findById(VIEWER)).thenReturn(Optional.of(viewer("Бат", "Сараа")));

        assertThatThrownBy(() -> service.setNameOnce(VIEWER, "Өөр", "Хүн"))
                .isInstanceOf(ConflictException.class)
                .hasMessage(Messages.NAME_ALREADY_SET);
        verify(events, never()).publish(any());
    }

    @Test
    void anUnknownUserIsNotFound() {
        when(users.trySetNameOnce(VIEWER, Role.VIEWER, "Бат", "Сараа")).thenReturn(0);
        when(users.findById(VIEWER)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.setNameOnce(VIEWER, "Бат", "Сараа"))
                .isInstanceOf(NotFoundException.class)
                .hasMessage(Messages.USER_NOT_FOUND);
        verify(events, never()).publish(any());
    }
}
