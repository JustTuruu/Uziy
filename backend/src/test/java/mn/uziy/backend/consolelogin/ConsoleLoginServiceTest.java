package mn.uziy.backend.consolelogin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.auth.LoginOutcome;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.LoginPhoneCheck;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.PhoneVerificationStartedRes;
import mn.uziy.backend.phoneverify.PhoneVerificationStatus;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.trusteddevice.DeviceTrust;
import mn.uziy.backend.trusteddevice.IssuedDevice;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class ConsoleLoginServiceTest {

    private static final String PHONE = "99001122";
    private static final String DEVICE = "device-secret";
    private static final String CHROME = "Mozilla/5.0 Chrome/141.0";
    private static final UUID CHECK = UUID.fromString("00000000-0000-0000-0000-000000000009");
    private static final OffsetDateTime UNTIL = OffsetDateTime.parse("2026-11-21T04:00:00Z");

    private final LoginPhoneCheck phoneChecks = mock(LoginPhoneCheck.class);
    private final VerifiedPhoneClaim verifiedPhones = mock(VerifiedPhoneClaim.class);
    private final DeviceTrust devices = mock(DeviceTrust.class);
    private final UserRepository users = mock(UserRepository.class);
    private final LoginAttemptLimiter limiter = new LoginAttemptLimiter(Clock.systemUTC());
    private final JwtService jwt = new JwtService(new AppProperties(
            new AppProperties.Jwt("a".repeat(64), 1), new AppProperties.Cors(List.of()),
            new AppProperties.Payments(false), new AppProperties.Push(false, "")));
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final ConsoleLoginServiceImpl service = new ConsoleLoginServiceImpl(phoneChecks, verifiedPhones, devices,
            users, limiter, jwt, new MeMapper(), new ConsoleLoginMapper(), events);

    private static UserEntity user(Role role) {
        UserEntity u = new UserEntity();
        u.setId(3L);
        u.setPhoneNumber(PHONE);
        u.setPasswordHash("hash");
        u.setRole(role);
        return u;
    }

    private static PhoneVerificationStartedRes opened() {
        return new PhoneVerificationStartedRes(CHECK, PHONE, "144773", "482916", "sms:144773?body=482916",
                "SMS илгээнэ үү", PhoneVerificationStatus.PENDING, OffsetDateTime.parse("2026-10-22T04:05:00Z"));
    }

    private static ConsoleLoginVerifyReq req() {
        return new ConsoleLoginVerifyReq(PHONE, CHECK);
    }

    private static PhoneVerificationPurpose purposeOf(Role role) {
        return role == Role.ADMIN ? PhoneVerificationPurpose.ADMIN_LOGIN : PhoneVerificationPurpose.COMPANY_LOGIN;
    }

    @Test
    void onlyTheConsoleRolesTakeTheStep() {
        assertThat(service.appliesTo(Role.ADMIN)).isTrue();
        assertThat(service.appliesTo(Role.COMPANY)).isTrue();
        assertThat(service.appliesTo(Role.VIEWER)).isFalse();
    }

    // ------- after the password -----------------------------------------------

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"ADMIN", "COMPANY"})
    void aRememberedBrowserIsSignedInWithoutAnSms(Role role) {
        when(devices.recognises(3L, DEVICE)).thenReturn(true);

        LoginOutcome outcome = service.afterPassword(user(role), DEVICE);

        assertThat(outcome).isInstanceOf(LoginOutcome.SignedIn.class);
        var res = ((LoginOutcome.SignedIn) outcome).response();
        assertThat(jwt.parse(res.token()).role()).isEqualTo(role);
        assertThat(res.user().id()).isEqualTo(3L);
        verifyNoInteractions(phoneChecks);
        verify(events).publish(new ConsoleSignedIn(3L, role, false));
    }

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"ADMIN", "COMPANY"})
    void anUnknownBrowserGetsTheSmsStepForItsOwnRoleWithThePhoneMasked(Role role) {
        when(devices.recognises(3L, null)).thenReturn(false);
        when(phoneChecks.openForLogin(PHONE, purposeOf(role))).thenReturn(opened());

        LoginOutcome outcome = service.afterPassword(user(role), null);

        assertThat(outcome).isInstanceOf(LoginOutcome.SecondStepRequired.class);
        ConsoleLoginChallenge.TwoStep step = ((LoginOutcome.SecondStepRequired) outcome).challenge().twoStep();
        assertThat(step.verificationId()).isEqualTo(CHECK);
        assertThat(step.phoneNumber()).isEqualTo("•••• 1122");
        assertThat(step.role()).isEqualTo(role);
        verify(events, never()).publish(any());
    }

    @Test
    void aViewerHasNoConsoleStep() {
        assertThatThrownBy(() -> service.afterPassword(user(Role.VIEWER), DEVICE))
                .isInstanceOf(IllegalArgumentException.class);
        verifyNoInteractions(phoneChecks, devices);
    }

    // ------- verify ------------------------------------------------------------

    @ParameterizedTest
    @EnumSource(value = Role.class, names = {"ADMIN", "COMPANY"})
    void aConfirmedCheckSignsInRemembersTheBrowserAndIsAudited(Role role) {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(role)));
        when(devices.trust(3L, CHROME)).thenReturn(new IssuedDevice(DEVICE, UNTIL));

        ConsoleLoginVerifiedRes res = service.verify(req(), CHROME);

        assertThat(jwt.parse(res.token()).role()).isEqualTo(role);
        assertThat(res.user().role()).isEqualTo(role);
        assertThat(res.deviceToken()).isEqualTo(DEVICE);
        assertThat(res.deviceTrustedUntil()).isEqualTo(UNTIL);
        assertThat(res.toString()).doesNotContain(DEVICE).doesNotContain(res.token());
        verify(verifiedPhones).claim(CHECK, PHONE, purposeOf(role));
        verify(events).publish(new ConsoleSignedIn(3L, role, true));
    }

    @Test
    void anUnconfirmedCheckIsRefusedWithoutATokenOrARememberedBrowser() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.COMPANY)));
        doThrow(new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED))
                .when(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.COMPANY_LOGIN);

        assertThatThrownBy(() -> service.verify(req(), CHROME))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        verify(devices, never()).trust(anyLong(), any());
        verify(events, never()).publish(any());
    }

    @Test
    void aViewerPhoneCannotUseTheConsoleStep() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.VIEWER)));

        assertThatThrownBy(() -> service.verify(req(), CHROME)).isInstanceOf(BadRequestException.class);
        verifyNoInteractions(verifiedPhones, devices, events);
    }

    @Test
    void anUnknownPhoneIsRefusedTheSameWay() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.verify(req(), CHROME))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
    }

    @Test
    void refusalsCountTowardsTheLoginLock() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            assertThatThrownBy(() -> service.verify(req(), null)).isInstanceOf(BadRequestException.class);
        }

        assertThatThrownBy(() -> service.verify(req(), null)).isInstanceOf(TooManyRequestsException.class);
    }
}
