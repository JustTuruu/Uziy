package mn.uziy.backend.otp;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class PasswordResetServiceTest {

    private static final String PHONE = "88112233";
    private static final ResetPasswordReq REQ = new ResetPasswordReq(PHONE, "123456", "new-password");

    private final OtpService otp = mock(OtpService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final PasswordResetServiceImpl service = new PasswordResetServiceImpl(otp, users, encoder);

    private static UserEntity user(Role role) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(PHONE);
        u.setPasswordHash("old");
        u.setRole(role);
        return u;
    }

    @Test
    void aValidCodeSetsTheNewPasswordHash() {
        UserEntity viewer = user(Role.VIEWER);
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(viewer));
        when(encoder.encode("new-password")).thenReturn("new-hash");

        service.reset(REQ);

        verify(otp).verifyAndConsume(PHONE, OtpPurpose.PASSWORD_RESET, "123456");
        assertThat(viewer.getPasswordHash()).isEqualTo("new-hash");
        verify(users).save(viewer);
    }

    @Test
    void aWrongCodeLeavesThePasswordAlone() {
        doThrow(new BadRequestException(OtpService.INVALID_CODE))
                .when(otp).verifyAndConsume(PHONE, OtpPurpose.PASSWORD_RESET, "123456");

        assertThatThrownBy(() -> service.reset(REQ)).isInstanceOf(BadRequestException.class);
        verify(users, never()).save(any());
    }

    @Test
    void anAdminPasswordCannotBeResetThisWay() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.ADMIN)));

        assertThatThrownBy(() -> service.reset(REQ))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(OtpService.INVALID_CODE);
        verify(users, never()).save(any());
    }
}
