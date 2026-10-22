package mn.uziy.backend.adminlogin;

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
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.AdminPhoneCheck;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.PhoneVerificationStartedRes;
import mn.uziy.backend.phoneverify.PhoneVerificationStatus;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import org.junit.jupiter.api.Test;

class AdminLoginServiceTest {

    private static final String PHONE = "99001122";
    private static final UUID CHECK = UUID.fromString("00000000-0000-0000-0000-000000000009");

    private final AdminPhoneCheck phoneChecks = mock(AdminPhoneCheck.class);
    private final VerifiedPhoneClaim verifiedPhones = mock(VerifiedPhoneClaim.class);
    private final UserRepository users = mock(UserRepository.class);
    private final LoginAttemptLimiter limiter = new LoginAttemptLimiter(Clock.systemUTC());
    private final JwtService jwt = new JwtService(new AppProperties(
            new AppProperties.Jwt("a".repeat(64), 1), new AppProperties.Cors(List.of()),
            new AppProperties.Payments(false), new AppProperties.Push(false, "")));
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final AdminLoginServiceImpl service = new AdminLoginServiceImpl(phoneChecks, verifiedPhones, users,
            limiter, jwt, new MeMapper(), new AdminLoginMapper(), events);

    private static UserEntity user(Role role) {
        UserEntity u = new UserEntity();
        u.setId(3L);
        u.setPhoneNumber(PHONE);
        u.setPasswordHash("hash");
        u.setRole(role);
        return u;
    }

    private AdminLoginVerifyReq req() {
        return new AdminLoginVerifyReq(PHONE, CHECK);
    }

    @Test
    void openAsksForAnAdminLoginCheckOfTheAccountsOwnPhoneAndMasksIt() {
        when(phoneChecks.openForAdminLogin(PHONE)).thenReturn(new PhoneVerificationStartedRes(CHECK, PHONE,
                "144773", "482916", "sms:144773?body=482916", "SMS илгээнэ үү", PhoneVerificationStatus.PENDING,
                OffsetDateTime.parse("2026-10-22T04:05:00Z")));

        AdminLoginChallenge.TwoStep step = service.open(user(Role.ADMIN)).twoStep();

        assertThat(step.verificationId()).isEqualTo(CHECK);
        assertThat(step.phoneNumber()).isEqualTo("•••• 1122");
        assertThat(step.shortcode()).isEqualTo("144773");
        assertThat(step.smsText()).isEqualTo("482916");
    }

    @Test
    void aConfirmedCheckSignsTheAdminInAndIsAudited() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.ADMIN)));

        AuthResponse res = service.verify(req());

        assertThat(res.token()).isNotBlank();
        assertThat(jwt.parse(res.token()).role()).isEqualTo(Role.ADMIN);
        assertThat(res.user().role()).isEqualTo(Role.ADMIN);
        verify(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.ADMIN_LOGIN);
        verify(events).publish(new AdminSignedIn(3L));
    }

    @Test
    void anUnconfirmedCheckIsRefusedWithoutAToken() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(Role.ADMIN)));
        doThrow(new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED))
                .when(verifiedPhones).claim(CHECK, PHONE, PhoneVerificationPurpose.ADMIN_LOGIN);

        assertThatThrownBy(() -> service.verify(req()))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        verify(events, never()).publish(any());
    }

    @Test
    void aViewerOrCompanyPhoneCannotUseTheAdminSecondStep() {
        for (Role role : List.of(Role.VIEWER, Role.COMPANY)) {
            when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(user(role)));

            assertThatThrownBy(() -> service.verify(req())).isInstanceOf(BadRequestException.class);
        }
        verifyNoInteractions(verifiedPhones, events);
    }

    @Test
    void anUnknownPhoneIsRefusedTheSameWay() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.verify(req()))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
    }

    @Test
    void refusalsCountTowardsTheLoginLock() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());
        for (int i = 0; i < LoginAttemptLimiter.MAX_FAILURES; i++) {
            assertThatThrownBy(() -> service.verify(req())).isInstanceOf(BadRequestException.class);
        }

        assertThatThrownBy(() -> service.verify(req())).isInstanceOf(TooManyRequestsException.class);
    }
}
