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
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.otp.OtpPurpose;
import mn.uziy.backend.otp.OtpService;
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
            new AppProperties.Push(false, "")));
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final OtpService otp = mock(OtpService.class);
    private final AuthServiceImpl service = new AuthServiceImpl(users, encoder, jwt,
            new UserFactory(), new MeMapper(), events, otp);

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

        AuthResponse res = service.login(new LoginReq("88112233", "password"));

        assertThat(res.token()).isNotBlank();
        assertThat(res.user().id()).isEqualTo(1L);
        assertThat(res.user().role()).isEqualTo(Role.VIEWER);
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
                "77000001", "password1", Gender.MALE, LocalDate.of(2000, 5, 5), "Улаанбаатар", "123456"));

        Me me = res.user();
        assertThat(me.id()).isEqualTo(100L);
        assertThat(me.role()).isEqualTo(Role.VIEWER);
        assertThat(me.city()).isEqualTo("Улаанбаатар");
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(Role.VIEWER);
        assertThat(saved.getValue().getPasswordHash()).isEqualTo("bcrypt-hash");
        verify(events).publish(new UserRegistered(100L, Role.VIEWER));
        verify(otp).verifyAndConsume("77000001", OtpPurpose.REGISTER, "123456");
    }

    @Test
    void registerViewerWithAWrongCodeCreatesNoUser() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(false);
        org.mockito.Mockito.doThrow(new mn.uziy.backend.common.BadRequestException(OtpService.INVALID_CODE))
                .when(otp).verifyAndConsume("77000001", OtpPurpose.REGISTER, "000000");

        assertThat(statusOf(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", Gender.MALE, LocalDate.of(2000, 1, 1), "Улаанбаатар", "000000"))))
                .isEqualTo(HttpStatus.BAD_REQUEST);
        org.mockito.Mockito.verify(users, org.mockito.Mockito.never()).save(any(UserEntity.class));
        org.mockito.Mockito.verifyNoInteractions(events);
    }

    @Test
    void registerViewerThrows409WhenPhoneAlreadyExists() {
        when(users.existsByPhoneNumber("77000001")).thenReturn(true);
        org.mockito.Mockito.verifyNoInteractions(events);
        assertThat(statusOf(() -> service.registerViewer(new RegisterViewerReq(
                "77000001", "password1", Gender.MALE, LocalDate.of(2000, 1, 1), "Улаанбаатар", "123456"))))
                .isEqualTo(HttpStatus.CONFLICT);
        org.mockito.Mockito.verifyNoInteractions(otp);
    }

    // ------- register company ----------------------------------------------

    @Test
    void registerCompanyCreatesCompanyRoleAndReturns201() {
        when(users.existsByPhoneNumber("88112233")).thenReturn(false);
        when(encoder.encode("password1")).thenReturn("hash");
        when(users.save(any(UserEntity.class))).thenAnswer(inv -> {
            UserEntity saved = inv.getArgument(0);
            saved.setId(42L);
            return saved;
        });

        AuthResponse res = service.registerCompany(
                new RegisterCompanyReq("88112233", "password1", "MobiCom"));

        assertThat(res.user().role()).isEqualTo(Role.COMPANY);
        assertThat(res.user().companyName()).isEqualTo("MobiCom");
        verify(events).publish(new UserRegistered(42L, Role.COMPANY));
    }

    @Test
    void registerCompanyThrows409WhenPhoneAlreadyExists() {
        when(users.existsByPhoneNumber(anyString())).thenReturn(true);
        assertThatThrownBy(() -> service.registerCompany(new RegisterCompanyReq("88112233", "password1", "X")))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void unauthorizedExceptionTypeIsUsedForBadCredentials() {
        when(users.findByPhoneNumber(anyString())).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.login(new LoginReq("99999999", "p")))
                .isInstanceOf(UnauthorizedException.class)
                .hasMessage(AuthServiceImpl.INVALID_CREDENTIALS);
    }
}
