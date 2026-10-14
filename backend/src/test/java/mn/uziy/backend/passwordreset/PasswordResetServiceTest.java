package mn.uziy.backend.passwordreset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

class PasswordResetServiceTest {

    private static final String PHONE = "88112233";
    private static final UUID CHECK = UUID.fromString("11111111-2222-3333-4444-555555555555");

    private final VerifiedPhoneClaim verifiedPhones = mock(VerifiedPhoneClaim.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final LoginAttemptLimiter loginLimiter =
            new LoginAttemptLimiter(Clock.fixed(Instant.parse("2026-10-14T04:00:00Z"), ZoneOffset.UTC));
    private final PasswordResetServiceImpl service =
            new PasswordResetServiceImpl(verifiedPhones, users, encoder, loginLimiter);

    private UserEntity account(Role role) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(PHONE);
        u.setRole(role);
        u.setPasswordHash("old-hash");
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(u));
        return u;
    }

    private static ResetPasswordReq req() {
        return new ResetPasswordReq(PHONE, CHECK, "newpass1");
    }

    @Test
    void spendsTheResetCheckAndStoresTheNewPasswordHash() {
        UserEntity viewer = account(Role.VIEWER);
        when(encoder.encode("newpass1")).thenReturn("new-hash");

        service.reset(req());

        verify(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.PASSWORD_RESET);
        assertThat(viewer.getPasswordHash()).isEqualTo("new-hash");
        verify(users).save(viewer);
    }

    @Test
    void anUnprovedPhoneKeepsTheOldPassword() {
        UserEntity viewer = account(Role.VIEWER);
        doThrow(new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED))
                .when(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.PASSWORD_RESET);

        assertThatThrownBy(() -> service.reset(req()))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        assertThat(viewer.getPasswordHash()).isEqualTo("old-hash");
        verify(users, never()).save(any());
    }

    @Test
    void aPhoneWithoutAViewerAccountIsRefusedWithoutSpendingTheCheck() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.reset(req())).isInstanceOf(BadRequestException.class);
        verifyNoInteractions(verifiedPhones);
    }

    @Test
    void aCompanyAccountCannotBeResetThisWay() {
        account(Role.COMPANY);

        assertThatThrownBy(() -> service.reset(req())).isInstanceOf(BadRequestException.class);
        verifyNoInteractions(verifiedPhones);
    }

    @Test
    void aResetLiftsALoginLockFromEarlierWrongPasswords() {
        account(Role.VIEWER);
        when(encoder.encode("newpass1")).thenReturn("new-hash");
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            loginLimiter.recordFailure(PHONE);
        }
        assertThatThrownBy(() -> loginLimiter.requireNotLocked(PHONE)).isInstanceOf(TooManyRequestsException.class);

        service.reset(req());

        loginLimiter.requireNotLocked(PHONE); // no longer throws
    }
}
