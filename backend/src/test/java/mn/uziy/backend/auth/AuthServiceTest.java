package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import java.time.OffsetDateTime;
import mn.uziy.backend.consolelogin.ConsoleLoginChallenge;
import mn.uziy.backend.consolelogin.ConsoleLoginGate;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.web.ApiExceptionHandler;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

class AuthServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final JwtService jwt = new JwtService(new AppProperties(
            new AppProperties.Jwt("a".repeat(64), 1), new AppProperties.Cors(java.util.List.of()), new AppProperties.Payments(false),
            new AppProperties.Push(false, ""), new AppProperties.ConsoleLogin(false)));
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final VerifiedPhoneClaim verifiedPhones = mock(VerifiedPhoneClaim.class);
    private final ConsoleLoginGate consoleLogin = mock(ConsoleLoginGate.class);
    private static final UUID CHECK = UUID.fromString("00000000-0000-0000-0000-000000000001");
    private final AuthServiceImpl service = new AuthServiceImpl(users, encoder, jwt,
            new UserFactory(), new MeMapper(), events, verifiedPhones,
            new LoginAttemptLimiter(java.time.Clock.systemUTC()),
            java.time.Clock.fixed(java.time.Instant.parse("2026-10-22T04:00:00Z"), java.time.ZoneOffset.UTC),
            consoleLogin);

    {
        when(consoleLogin.appliesTo(Role.ADMIN)).thenReturn(true);
        when(consoleLogin.appliesTo(Role.COMPANY)).thenReturn(true);
    }

    private AuthResponse signedIn(LoginOutcome outcome) {
        assertThat(outcome).isInstanceOf(LoginOutcome.SignedIn.class);
        return ((LoginOutcome.SignedIn) outcome).response();
    }

    private UserEntity seedUser(Role role) {
        UserEntity u = new UserEntity();
        u.setId(1L);
        u.setPhoneNumber("88112233");
        u.setPasswordHash("hashed");
        u.setRole(role);
        u.setGender(Gender.MALE);
        u.setBirthDate(LocalDate.of(2000, 1, 1));
        u.setCity("Улаанбаатар");
        u.setBalance(0.0);
        return u;
    }

    private static HttpStatus statusOf(Runnable block) {
        Throwable t = org.assertj.core.api.Assertions.catchThrowable(block::run);
        assertThat(t).isInstanceOf(mn.uziy.backend.common.DomainException.class);
        return ApiExceptionHandler.statusOf((mn.uziy.backend.common.DomainException) t);
    }

    // ------- login ----------------------------------------------------------

    @Test
    void loginReturnsTokenAndMeOnCorrectCredentials() {
        UserEntity u = seedUser(Role.VIEWER);
        when(users.findByPhoneNumber("88112233")).thenReturn(Optional.of(u));
        when(encoder.matches("password", "hashed")).thenReturn(true);

        AuthResponse res = signedIn(service.login(new LoginReq("88112233", "password")));

        assertThat(res.token()).isNotBlank();
        assertThat(res.user().id()).isEqualTo(1L);
        assertThat(res.user().role()).isEqualTo(Role.VIEWER);
        org.mockito.Mockito.verify(consoleLogin, org.mockito.Mockito.never()).afterPassword(any(), any());
    }

    /** A viewer's login never looks at a device token: the app has none, and the SMS step is for consoles only. */
    @Test
    void aViewersDeviceTokenIsIgnored() {
        when(users.findByPhoneNumber("88112233")).thenReturn(Optional.of(seedUser(Role.VIEWER)));
        when(encoder.matches("password", "hashed")).thenReturn(true);

        signedIn(service.login(new LoginReq("88112233", "password", "some-device-token")));

        org.mockito.Mockito.verify(consoleLogin, org.mockito.Mockito.never()).afterPassword(any(), any());
    }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.EnumSource(value = Role.class, names = {"ADMIN", "COMPANY"})
    void aConsoleAccountWithTheRightPasswordIsHandedToTheConsoleStepWithItsDeviceToken(Role role) {
        UserEntity user = seedUser(role);
        when(users.findByPhoneNumber("88112233")).thenReturn(Optional.of(user));
        when(encoder.matches("password", "hashed")).thenReturn(true);
        ConsoleLoginChallenge challenge = new ConsoleLoginChallenge(new ConsoleLoginChallenge.TwoStep(CHECK,
                "•••• 2233", role, "144773", "123456", "sms:144773?body=123456", "SMS илгээнэ үү",
                OffsetDateTime.parse("2026-10-22T04:05:00Z")));
        when(consoleLogin.afterPassword(user, "device-1")).thenReturn(new LoginOutcome.SecondStepRequired(challenge));

        LoginOutcome outcome = service.login(new LoginReq("88112233", "password", "device-1"));

        assertThat(outcome).isEqualTo(new LoginOutcome.SecondStepRequired(challenge));
    }

    @Test
    void aWrongConsolePasswordOpensNoPhoneCheckEvenWithADeviceToken() {
        when(users.findByPhoneNumber("88112233")).thenReturn(Optional.of(seedUser(Role.COMPANY)));
        when(encoder.matches("wrong", "hashed")).thenReturn(false);

        assertThat(statusOf(() -> service.login(new LoginReq("88112233", "wrong", "device-1"))))
                .isEqualTo(HttpStatus.UNAUTHORIZED);
        org.mockito.Mockito.verify(consoleLogin, org.mockito.Mockito.never()).afterPassword(any(), any());
    }

    @Test
    void loginThrows401OnUnknownPhone() {
        when(users.findByPhoneNumber(anyString())).thenReturn(Optional.empty());
        assertThat(statusOf(() -> service.login(new LoginReq("99999999", "password"))))
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void loginThrows401OnBadPassword() {
        when(users.findByPhoneNumber("88112233")).thenReturn(Optional.of(seedUser(Role.VIEWER)));
        when(encoder.matches("wrong", "hashed")).thenReturn(false);
        assertThat(statusOf(() -> service.login(new LoginReq("88112233", "wrong"))))
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    // ------- register viewer -----------------------------------------------

    @Test
    void registerViewerCreatesUserAndReturns201() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(false);
        when(encoder.encode("password1")).thenReturn("bcrypt-hash");
        when(users.save(any(UserEntity.class))).thenAnswer(inv -> {
            UserEntity saved = inv.getArgument(0);
            saved.setId(100L);
            return saved;
        });

        AuthResponse res = service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2000, 5, 5), "Улаанбаатар",
                "Баянзүрх", CHECK));

        Me me = res.user();
        assertThat(me.id()).isEqualTo(100L);
        assertThat(me.role()).isEqualTo(Role.VIEWER);
        assertThat(me.city()).isEqualTo("Улаанбаатар");
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(Role.VIEWER);
        assertThat(saved.getValue().getPasswordHash()).isEqualTo("bcrypt-hash");
        verify(events).publish(new UserRegistered(100L, Role.VIEWER));
        verify(verifiedPhones).claim(CHECK, "77000001", PhoneVerificationPurpose.REGISTER);
    }

    @Test
    void registerViewerInTheCapitalWithoutADistrictSpendsNothing() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(false);

        assertThat(statusOf(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2000, 1, 1), "Улаанбаатар", CHECK))))
                .isEqualTo(HttpStatus.BAD_REQUEST);
        org.mockito.Mockito.verifyNoInteractions(verifiedPhones);
        org.mockito.Mockito.verify(users, org.mockito.Mockito.never()).save(any(UserEntity.class));
    }

    /** Audit 2026-10-22: the minimum age was only checked by the app's date picker. */
    @Test
    void registerViewerYoungerThan13IsRefusedBeforeThePhoneCheckIsSpent() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(false);

        assertThatThrownBy(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2015, 1, 1), "Улаанбаатар",
                "Баянзүрх", CHECK)))
                .hasMessage(ViewerAgeRule.TOO_YOUNG);
        org.mockito.Mockito.verifyNoInteractions(verifiedPhones);
        org.mockito.Mockito.verify(users, org.mockito.Mockito.never()).save(any(UserEntity.class));
    }

    @Test
    void registerViewerWithAnUnverifiedPhoneCreatesNoUser() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(false);
        org.mockito.Mockito.doThrow(new mn.uziy.backend.common.BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED))
                .when(verifiedPhones).claim(CHECK, "77000001", PhoneVerificationPurpose.REGISTER);

        assertThat(statusOf(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2000, 1, 1), "Улаанбаатар",
                "Баянзүрх", CHECK))))
                .isEqualTo(HttpStatus.BAD_REQUEST);
        org.mockito.Mockito.verify(users, org.mockito.Mockito.never()).save(any(UserEntity.class));
        org.mockito.Mockito.verifyNoInteractions(events);
    }

    @Test
    void registerViewerThrows409WhenPhoneAlreadyExists() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(true);
        org.mockito.Mockito.verifyNoInteractions(events);
        assertThat(statusOf(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", "Бат", "Болд", Gender.MALE, LocalDate.of(2000, 1, 1), "Улаанбаатар", CHECK))))
                .isEqualTo(HttpStatus.CONFLICT);
        org.mockito.Mockito.verifyNoInteractions(verifiedPhones);
    }

    @Test
    void unauthorizedExceptionTypeIsUsedForBadCredentials() {
        when(users.findByPhoneNumber(anyString())).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.login(new LoginReq("99999999", "p")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage(AuthServiceImpl.INVALID_CREDENTIALS);
    }
}
