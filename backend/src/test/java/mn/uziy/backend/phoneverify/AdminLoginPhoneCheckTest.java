package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/** The admin login's phone checks: opened only by the login, short-lived, spent only for the admin login. */
class AdminLoginPhoneCheckTest {

    private static final String PHONE = "99001122";
    private static final Instant T0 = Instant.parse("2026-10-22T04:00:00Z");
    private static final UUID ID = UUID.fromString("11111111-2222-3333-4444-555555555555");
    private static final PhoneVerificationPurpose ADMIN_LOGIN = PhoneVerificationPurpose.ADMIN_LOGIN;

    private final PhoneVerificationRepository verifications = mock(PhoneVerificationRepository.class);
    private final PhoneVerificationGateway gateway = mock(PhoneVerificationGateway.class);
    private final VerificationCodeGenerator codes = mock(VerificationCodeGenerator.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PhoneVerificationServiceImpl service = new PhoneVerificationServiceImpl(verifications, gateway,
            codes, users, new PhoneVerificationMapper(), Clock.fixed(T0, ZoneOffset.UTC));

    private static OffsetDateTime at(Instant i) {
        return OffsetDateTime.ofInstant(i, ZoneOffset.UTC);
    }

    @Test
    void thePublicEndpointCannotOpenAnAdminLoginCheck() {
        assertThatThrownBy(() -> service.start(PHONE, ADMIN_LOGIN))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(PhoneVerificationService.PURPOSE_NOT_OFFERED);
        verifyNoInteractions(gateway, verifications);
    }

    @Test
    void theLoginOpensACheckMarkedForTheAdminLogin() {
        when(codes.next()).thenReturn("482916");
        when(gateway.start(PHONE, "482916")).thenReturn(new PhoneVerificationSession("vmn-1", "144773", "482916",
                "sms:144773?body=482916", "Та SMS илгээнэ үү", at(T0.plusSeconds(300))));
        when(verifications.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PhoneVerificationStartedRes res = service.openForAdminLogin(PHONE);

        ArgumentCaptor<PhoneVerificationEntity> saved = ArgumentCaptor.forClass(PhoneVerificationEntity.class);
        verify(verifications).save(saved.capture());
        assertThat(saved.getValue().getPurpose()).isEqualTo(ADMIN_LOGIN);
        assertThat(saved.getValue().getPhoneNumber()).isEqualTo(PHONE);
        assertThat(res.verificationId()).isEqualTo(saved.getValue().getId());
        assertThat(res.shortcode()).isEqualTo("144773");
        // No account lookup: the login already proved the password.
        verifyNoInteractions(users);
    }

    @Test
    void theLoginStillRespectsTheSmsCooldown() {
        PhoneVerificationEntity latest = new PhoneVerificationEntity();
        latest.setCreatedAt(at(T0.minusSeconds(10)));
        when(verifications.findFirstByPhoneNumberOrderByCreatedAtDesc(PHONE)).thenReturn(Optional.of(latest));

        assertThatThrownBy(() -> service.openForAdminLogin(PHONE)).isInstanceOf(TooManyRequestsException.class);
        verifyNoInteractions(gateway);
    }

    @Test
    void anAdminLoginCheckMustBeSpentWithinFiveMinutesOfTheSms() {
        PhoneVerificationEntity row = new PhoneVerificationEntity();
        row.setId(ID);
        row.setPhoneNumber(PHONE);
        row.setPurpose(ADMIN_LOGIN);
        row.setStatus(PhoneVerificationStatus.VERIFIED);
        when(verifications.findById(ID)).thenReturn(Optional.of(row));
        when(verifications.tryClaim(ID, PHONE, ADMIN_LOGIN, at(T0.minus(Duration.ofMinutes(5))))).thenReturn(1);

        service.claim(ID, PHONE, ADMIN_LOGIN);

        verify(verifications).tryClaim(ID, PHONE, ADMIN_LOGIN, at(T0.minus(Duration.ofMinutes(5))));
    }

    @Test
    void anAdminLoginCheckCannotFinishARegistration() {
        PhoneVerificationEntity row = new PhoneVerificationEntity();
        row.setId(ID);
        row.setPhoneNumber(PHONE);
        row.setPurpose(ADMIN_LOGIN);
        row.setStatus(PhoneVerificationStatus.VERIFIED);
        when(verifications.findById(ID)).thenReturn(Optional.of(row));

        assertThatThrownBy(() -> service.claim(ID, PHONE, PhoneVerificationPurpose.REGISTER))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void theAdminLoginWindowIsShorterThanRegistrations() {
        assertThat(ADMIN_LOGIN.claimWindow()).isEqualTo(Duration.ofMinutes(5));
        assertThat(PhoneVerificationPurpose.REGISTER.claimWindow()).isEqualTo(PhoneVerificationServiceImpl.CLAIM_WINDOW);
        assertThat(PhoneVerificationPurpose.PASSWORD_RESET.claimWindow()).isEqualTo(Duration.ofMinutes(30));
    }
}
