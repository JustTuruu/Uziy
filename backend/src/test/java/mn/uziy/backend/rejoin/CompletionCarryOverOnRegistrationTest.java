package mn.uziy.backend.rejoin;

import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.auth.UserRegistered;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class CompletionCarryOverOnRegistrationTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CompletionCarryOver carryOver = mock(CompletionCarryOver.class);
    private final CompletionCarryOverOnRegistration listener = new CompletionCarryOverOnRegistration(users, carryOver);

    private static UserEntity account(long id, String phone, Role role) {
        UserEntity u = new UserEntity();
        u.setId(id);
        u.setPhoneNumber(phone);
        u.setRole(role);
        return u;
    }

    @Test
    void aNewViewerInheritsByTheirPhone() {
        when(users.findById(77L)).thenReturn(Optional.of(account(77L, "99112233", Role.VIEWER)));

        listener.onUserRegistered(new UserRegistered(77L, Role.VIEWER));

        verify(carryOver).carryOverToNewAccount(77L, "99112233");
    }

    @Test
    void companiesAndAdminsInheritNothing() {
        listener.onUserRegistered(new UserRegistered(5L, Role.COMPANY));
        listener.onUserRegistered(new UserRegistered(6L, Role.ADMIN));

        verify(carryOver, never()).carryOverToNewAccount(anyLong(), anyString());
    }
}
