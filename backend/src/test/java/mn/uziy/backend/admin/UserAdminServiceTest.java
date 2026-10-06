package mn.uziy.backend.admin;

import static mn.uziy.backend.admin.AdminTestData.company;
import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class UserAdminServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final UserAdminServiceImpl service = new UserAdminServiceImpl(users, new UserMapper());

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

        List<UserDto> list = service.list();

        assertThat(list).hasSize(1);
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
        when(users.findById(10L)).thenReturn(Optional.of(u));
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        when(users.save(saved.capture())).thenAnswer(inv -> inv.getArgument(0));

        UserDto dto = service.verify(10L);

        assertThat(dto.isVerified()).isTrue();
        assertThat(saved.getValue().isVerified()).isTrue();
    }

    @Test
    void getUserReturnsTheUser() {
        when(users.findById(500L)).thenReturn(Optional.of(company(500L, "MobiCom")));
        UserDto u = service.get(500L);
        assertThat(u.id()).isEqualTo(500L);
        assertThat(u.role()).isEqualTo(Role.COMPANY);
        assertThat(u.companyName()).isEqualTo("MobiCom");
    }

    @Test
    void getUser404sWhenMissing() {
        when(users.findById(anyLong())).thenReturn(Optional.empty());
        var ex = assertFailsWithHttp(() -> service.get(999L));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
