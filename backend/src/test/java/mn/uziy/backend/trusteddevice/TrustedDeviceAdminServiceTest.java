package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class TrustedDeviceAdminServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final TrustedDeviceRevoker revoker = mock(TrustedDeviceRevoker.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final TrustedDeviceAdminServiceImpl service = new TrustedDeviceAdminServiceImpl(users, revoker, events);

    @Test
    void forgetsEveryBrowserOfTheAccountAndAnnouncesWhoDidIt() {
        when(users.existsById(12L)).thenReturn(true);
        when(revoker.revokeAll(12L)).thenReturn(2);

        service.forgetAll(12L, 1L);

        verify(revoker).revokeAll(12L);
        verify(events).publish(new TrustedDevicesForgotten(12L, 1L, 2));
    }

    @Test
    void anUnknownAccountIs404AndChangesNothing() {
        when(users.existsById(12L)).thenReturn(false);

        assertThatThrownBy(() -> service.forgetAll(12L, 1L))
                .isInstanceOf(NotFoundException.class)
                .hasMessage(Messages.USER_NOT_FOUND);
        verifyNoInteractions(revoker, events);
    }
}
