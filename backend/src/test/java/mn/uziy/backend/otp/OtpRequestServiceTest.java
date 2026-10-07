package mn.uziy.backend.otp;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;

import java.util.Optional;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class OtpRequestServiceTest {

    private static final String PHONE = "88112233";

    private final OtpService otp = mock(OtpService.class);
    private final UserRepository users = mock(UserRepository.class);
    private final OtpRequestServiceImpl service = new OtpRequestServiceImpl(otp, users);

    private static UserEntity user(Role role) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(PHONE);
        u.setRole(role);
        return u;
    }

    @Test
    void registerSendsACodeToAFreePhone() {
        when(users.existsByPhoneNumber(PHONE)).thenReturn(false);

        service.requestCode(PHONE, OtpPurpose.REGISTER);

        verify(otp).issue(PHONE, OtpPurpose.REGISTER);
    }

    @Test
    void registerRefusesAPhoneThatAlreadyHasAnAccount() {
        when(users.existsByPhoneNumber(PHONE)).thenReturn(true);

        assertThatThrownBy(() -> service.requestCode(PHONE, OtpPurpose.REGISTER))
                .isInstanceOf(ConflictException.class)
                .hasMessage(OtpRequestServiceImpl.PHONE_TAKEN);
        verify(otp, never()).issue(any(), any());
    }

    @Test
    void passwordResetSendsACodeToAnExistingViewer() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.VIEWER)));

        service.requestCode(PHONE, OtpPurpose.PASSWORD_RESET);

        verify(otp).issue(PHONE, OtpPurpose.PASSWORD_RESET);
    }

    @Test
    void passwordResetForAnUnknownPhoneSilentlyDoesNothing() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());

        service.requestCode(PHONE, OtpPurpose.PASSWORD_RESET);

        verify(otp, never()).issue(any(), any());
    }

    @Test
    void passwordResetNeverSendsToAdminsOrCompanies() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.ADMIN)));

        service.requestCode(PHONE, OtpPurpose.PASSWORD_RESET);

        verify(otp, never()).issue(any(), any());
    }
}
