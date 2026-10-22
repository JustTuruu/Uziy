package mn.uziy.backend.passwordreset;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
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
    private static final Instant NOW = Instant.parse("2026-10-14T04:00:00Z");
    private final Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
    private final LoginAttemptLimiter loginLimiter = new LoginAttemptLimiter(clock);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final PasswordResetServiceImpl service =
            new PasswordResetServiceImpl(verifiedPhones, users, encoder, loginLimiter, clock, events);

    private void viewerExists() {
        when(users.trySetPassword(eq(PHONE), eq(Role.VIEWER), any(), any())).thenReturn(1);
    }

    private static ResetPasswordReq req() {
        return new ResetPasswordReq(PHONE, CHECK, "newpass1");
    }

    @Test
    void spendsTheResetCheckThenSetsTheNewHashAndTheChangeTime() {
        viewerExists();
        when(encoder.encode("newpass1")).thenReturn("new-hash");

        service.reset(req());

        var order = inOrder(verifiedPhones, users);
        order.verify(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.PASSWORD_RESET);
        order.verify(users).trySetPassword(PHONE, Role.VIEWER, "new-hash", OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC));
    }

    /**
     * Regression (audit 2026-10-22): the account used to be loaded, then saved back after the provider call; the
     * save wrote the balance it had read over a payout made in between. Only the one-column UPDATE may run now.
     */
    @Test
    void neverLoadsOrSavesTheAccountSoABalanceCannotBeWrittenBack() {
        viewerExists();
        when(encoder.encode("newpass1")).thenReturn("new-hash");

        service.reset(req());

        verify(users, never()).save(any());
        verify(users, never()).findByPhoneNumber(any());
        verify(users, never()).findById(any());
    }

    @Test
    void anUnprovedPhoneKeepsTheOldPassword() {
        doThrow(new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED))
                .when(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.PASSWORD_RESET);

        assertThatThrownBy(() -> service.reset(req()))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        verify(users, never()).trySetPassword(any(), any(), any(), any());
    }

    /** Observers (remembered browsers) must forget what the old password unlocked. */
    @Test
    void announcesTheResetWithTheAccountIdOnly() {
        viewerExists();
        when(encoder.encode("newpass1")).thenReturn("new-hash");
        when(users.findIdByPhoneNumber(PHONE)).thenReturn(Optional.of(42L));

        service.reset(req());

        verify(events).publish(new PasswordReset(42L));
    }

    @Test
    void aRefusedResetAnnouncesNothing() {
        when(users.trySetPassword(eq(PHONE), eq(Role.VIEWER), any(), any())).thenReturn(0);

        assertThatThrownBy(() -> service.reset(req())).isInstanceOf(BadRequestException.class);
        verify(events, never()).publish(any());
    }

    /** No viewer with that phone (none, or a company/admin): refused, so the transaction gives the check back. */
    @Test
    void aPhoneWithoutAViewerAccountIsRefused() {
        when(users.trySetPassword(eq(PHONE), eq(Role.VIEWER), any(), any())).thenReturn(0);
        when(encoder.encode("newpass1")).thenReturn("new-hash");

        assertThatThrownBy(() -> service.reset(req()))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
    }

    @Test
    void aResetLiftsALoginLockFromEarlierWrongPasswords() {
        viewerExists();
        when(encoder.encode("newpass1")).thenReturn("new-hash");
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            loginLimiter.recordFailure(PHONE);
        }
        assertThatThrownBy(() -> loginLimiter.requireNotLocked(PHONE)).isInstanceOf(TooManyRequestsException.class);

        service.reset(req());

        loginLimiter.requireNotLocked(PHONE); // no longer throws
    }
}
