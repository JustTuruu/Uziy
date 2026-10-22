package mn.uziy.backend.admin;

import static mn.uziy.backend.admin.AdminTestData.company;
import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class UserAdminServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final DataAccessLogRepository accessLog = mock(DataAccessLogRepository.class);
    private final UserAdminServiceImpl service = new UserAdminServiceImpl(users, new UserMapper(), accessLog);
    private static final long ADMIN = 1L;

    @Test
    void listUsersMapsAllUsersToUserDto() {
        UserEntity u = new UserEntity();
        u.setId(10L);
        u.setPhoneNumber("88112233");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setGender(Gender.MALE);
        u.setBirthDate(LocalDate.now().minusYears(30));
        u.setCity("Улаанбаатар");
        u.setBalance(5000.0);
        u.setVerified(true);
        when(users.findAll()).thenReturn(List.of(u));

        List<UserDto> list = service.list(ADMIN);

        assertThat(list).hasSize(1);
        verify(accessLog).record(ADMIN, UserAdminServiceImpl.ACTION_LIST, "");
        assertThat(list.get(0).age()).isEqualTo(30);
        assertThat(list.get(0).isVerified()).isTrue();
    }

    @Test
    void verifySetsIsVerifiedToTrue() {
        UserEntity u = new UserEntity();
        u.setId(10L);
        u.setPhoneNumber("1");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setVerified(false);
        when(users.markVerified(10L)).thenAnswer(inv -> {
            u.setVerified(true);
            return 1;
        });
        when(users.findById(10L)).thenReturn(Optional.of(u));

        UserDto dto = service.verify(10L);

        assertThat(dto.isVerified()).isTrue();
        // One UPDATE of the flag; a loaded copy is never saved back over a newer balance.
        verify(users, never()).save(any());
        org.mockito.Mockito.verifyNoInteractions(accessLog);
    }

    @Test
    void verifyingAMissingUserIs404() {
        when(users.markVerified(99L)).thenReturn(0);
        assertThatThrownBy(() -> service.verify(99L)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void getUserReturnsTheUser() {
        when(users.findById(500L)).thenReturn(Optional.of(company(500L, "MobiCom")));
        UserDto u = service.get(500L, ADMIN);
        assertThat(u.id()).isEqualTo(500L);
        verify(accessLog).record(ADMIN, UserAdminServiceImpl.ACTION_GET, "user=500");
        assertThat(u.role()).isEqualTo(Role.COMPANY);
        assertThat(u.companyName()).isEqualTo("MobiCom");
    }

    @Test
    void getUser404sWhenMissing() {
        when(users.findById(anyLong())).thenReturn(Optional.empty());
        var ex = assertFailsWithHttp(() -> service.get(999L, ADMIN));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        org.mockito.Mockito.verifyNoInteractions(accessLog);
    }
}
