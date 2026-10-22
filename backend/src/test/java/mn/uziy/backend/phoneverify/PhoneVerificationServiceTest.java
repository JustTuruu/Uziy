package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
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
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.UnavailableException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;

class PhoneVerificationServiceTest {

    private static final String PHONE = "88112233";
    private static final Instant T0 = Instant.parse("2026-10-13T04:00:00Z");
    private static final UUID ID = UUID.fromString("11111111-2222-3333-4444-555555555555");

    private static final PhoneVerificationPurpose REGISTER = PhoneVerificationPurpose.REGISTER;
    private static final PhoneVerificationPurpose RESET = PhoneVerificationPurpose.PASSWORD_RESET;

    private final PhoneVerificationRepository verifications = mock(PhoneVerificationRepository.class);
    private final PhoneVerificationGateway gateway = mock(PhoneVerificationGateway.class);
    private final VerificationCodeGenerator codes = mock(VerificationCodeGenerator.class);
    private final UserRepository users = mock(UserRepository.class);
    private final PhoneVerificationServiceImpl service = new PhoneVerificationServiceImpl(verifications, gateway,
            codes, users, new PhoneVerificationMapper(), Clock.fixed(T0, ZoneOffset.UTC));

    private static OffsetDateTime at(Instant i) {
        return OffsetDateTime.ofInstant(i, ZoneOffset.UTC);
    }

    private static PhoneVerificationSession session() {
        return new PhoneVerificationSession("vmn-1", "144773", "482916", "sms:144773?body=482916",
                "Та өөрийн 88112233 дугаараас 144773 дугаарт \"482916\" гэж SMS илгээнэ үү.",
                at(T0.plusSeconds(300)));
    }

    private static PhoneVerificationEntity row(PhoneVerificationStatus status, Instant expires) {
        PhoneVerificationEntity r = new PhoneVerificationEntity();
        r.setId(ID);
        r.setPhoneNumber(PHONE);
        r.setProviderSessionId("vmn-1");
        r.setStatus(status);
        r.setCreatedAt(at(T0.minusSeconds(30)));
        r.setExpiresAt(at(expires));
        return r;
    }

    private void stored(PhoneVerificationEntity r) {
        when(verifications.findById(ID)).thenReturn(Optional.of(r));
    }

    // ------- start ---------------------------------------------------------

    @Test
    void startOpensAProviderSessionWithAFreshSixDigitCodeAndPassesTheInstructionThrough() {
        when(codes.next()).thenReturn("482916");
        when(gateway.start(PHONE, "482916")).thenReturn(session());
        when(verifications.save(any())).thenAnswer(inv -> inv.getArgument(0));

        PhoneVerificationStartedRes res = service.start(PHONE, REGISTER);

        ArgumentCaptor<PhoneVerificationEntity> saved = ArgumentCaptor.forClass(PhoneVerificationEntity.class);
        verify(verifications).save(saved.capture());
        assertThat(saved.getValue().getProviderSessionId()).isEqualTo("vmn-1");
        assertThat(saved.getValue().getPurpose()).isEqualTo(REGISTER);
        assertThat(saved.getValue().getStatus()).isEqualTo(PhoneVerificationStatus.PENDING);
        assertThat(saved.getValue().getCreatedAt()).isEqualTo(at(T0));
        assertThat(res.verificationId()).isEqualTo(saved.getValue().getId());
        assertThat(res.smsText()).isEqualTo("482916");
        assertThat(res.smsUri()).isEqualTo("sms:144773?body=482916");
        assertThat(res.displayInstruction()).isEqualTo(session().displayInstruction());
        assertThat(res.expiresAt()).isEqualTo(at(T0.plusSeconds(300)));
    }

    @Test
    void startRefusesAPhoneThatAlreadyHasAnAccount() {
        when(users.existsByPhoneNumber(PHONE)).thenReturn(true);

        assertThatThrownBy(() -> service.start(PHONE, REGISTER))
                .isInstanceOf(ConflictException.class)
                .hasMessage(PhoneVerificationService.PHONE_TAKEN);
        verifyNoInteractions(gateway);
    }

    @Test
    void startWithinTheCooldownIsRefusedSoTheUserIsNotChargedForAnotherSms() {
        PhoneVerificationEntity latest = row(PhoneVerificationStatus.PENDING, T0.plusSeconds(270));
        latest.setCreatedAt(at(T0.minus(PhoneVerificationServiceImpl.COOLDOWN).plusSeconds(1)));
        when(verifications.findFirstByPhoneNumberOrderByCreatedAtDesc(PHONE)).thenReturn(Optional.of(latest));

        assertThatThrownBy(() -> service.start(PHONE, REGISTER))
                .isInstanceOf(TooManyRequestsException.class)
                .hasMessage(PhoneVerificationService.TOO_SOON);
        verifyNoInteractions(gateway);
    }

    /** Regression (2026-10-22 audit): parallel starts both passed the cool-down — the read now runs under a lock. */
    @Test
    void startTakesThePerPhoneLockBeforeReadingTheLimits() {
        when(codes.next()).thenReturn("482916");
        when(gateway.start(PHONE, "482916")).thenReturn(session());
        when(verifications.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.start(PHONE, REGISTER);

        InOrder order = inOrder(verifications, gateway);
        order.verify(verifications).lockPhone(PhoneVerificationServiceImpl.START_LOCK_NAMESPACE, PHONE);
        order.verify(verifications).findFirstByPhoneNumberOrderByCreatedAtDesc(PHONE);
        order.verify(gateway).start(PHONE, "482916");
        order.verify(verifications).save(any());
    }

    @Test
    void aTakenPhoneAnswersConflictEvenInsideTheCooldownAndTakesNoLock() {
        PhoneVerificationEntity latest = row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(270));
        latest.setCreatedAt(at(T0.minusSeconds(1)));
        when(verifications.findFirstByPhoneNumberOrderByCreatedAtDesc(PHONE)).thenReturn(Optional.of(latest));
        when(users.existsByPhoneNumber(PHONE)).thenReturn(true);

        assertThatThrownBy(() -> service.start(PHONE, REGISTER))
                .isInstanceOf(ConflictException.class)
                .hasMessage(PhoneVerificationService.PHONE_TAKEN);
        verifyNoInteractions(gateway);
        verify(verifications, never()).lockPhone(anyInt(), anyString());
    }

    @Test
    void startPastTheHourlyLimitIsRefused() {
        when(verifications.countByPhoneNumberAndCreatedAtAfter(
                PHONE, at(T0.minus(PhoneVerificationServiceImpl.HOURLY_WINDOW))))
                .thenReturn((long) PhoneVerificationServiceImpl.MAX_PER_HOUR);

        assertThatThrownBy(() -> service.start(PHONE, REGISTER))
                .isInstanceOf(TooManyRequestsException.class)
                .hasMessage(PhoneVerificationService.TOO_MANY);
    }

    @Test
    void aProviderFailureOnStartIs503AndStoresNothing() {
        when(codes.next()).thenReturn("482916");
        when(gateway.start(anyString(), anyString()))
                .thenThrow(new PhoneVerificationGatewayException("verify.mn create session answered 401"));

        assertThatThrownBy(() -> service.start(PHONE, REGISTER))
                .isInstanceOf(UnavailableException.class)
                .hasMessage(PhoneVerificationService.START_FAILED);
        verify(verifications, never()).save(any());
    }

    // ------- check ---------------------------------------------------------

    @Test
    void checkAnUnknownIdIs404() {
        when(verifications.findById(ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.check(ID)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void checkStaysPendingWhileTheProviderIsStillWaiting() {
        stored(row(PhoneVerificationStatus.PENDING, T0.plusSeconds(200)));
        when(gateway.status("vmn-1")).thenReturn(PhoneVerificationStatus.PENDING);

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.PENDING);
        verify(verifications, never()).save(any());
    }

    @Test
    void checkTurnsPendingIntoVerifiedOnceTheSmsArrived() {
        PhoneVerificationEntity r = row(PhoneVerificationStatus.PENDING, T0.plusSeconds(200));
        stored(r);
        when(gateway.status("vmn-1")).thenReturn(PhoneVerificationStatus.VERIFIED);

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.VERIFIED);
        assertThat(r.getVerifiedAt()).isEqualTo(at(T0));
        verify(verifications).save(r);
    }

    @Test
    void aVerifiedCheckIsNeverAskedAboutAgain() {
        stored(row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200)));

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.VERIFIED);
        verifyNoInteractions(gateway);
    }

    @Test
    void checkPastExpiresAtIsExpiredWithoutAskingTheProvider() {
        PhoneVerificationEntity r = row(PhoneVerificationStatus.PENDING, T0);
        stored(r);

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.EXPIRED);
        verifyNoInteractions(gateway);
        verify(verifications).save(r);
    }

    @Test
    void checkTakesTheProvidersExpiredAnswer() {
        stored(row(PhoneVerificationStatus.PENDING, T0.plusSeconds(200)));
        when(gateway.status("vmn-1")).thenReturn(PhoneVerificationStatus.EXPIRED);

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.EXPIRED);
    }

    @Test
    void aProviderOutageDuringCheckLeavesThePendingStateSoTheAppPollsAgain() {
        stored(row(PhoneVerificationStatus.PENDING, T0.plusSeconds(200)));
        when(gateway.status("vmn-1")).thenThrow(new PhoneVerificationGatewayException("timeout"));

        assertThat(service.check(ID).status()).isEqualTo(PhoneVerificationStatus.PENDING);
        verify(verifications, never()).save(any());
    }

    // ------- claim ---------------------------------------------------------

    @Test
    void claimSpendsAConfirmedCheckForThatPhone() {
        stored(row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200)));
        when(verifications.tryClaim(ID, PHONE, REGISTER, at(T0.minus(PhoneVerificationServiceImpl.CLAIM_WINDOW))))
                .thenReturn(1);

        service.claim(ID, PHONE, REGISTER);

        verify(verifications).tryClaim(ID, PHONE, REGISTER, at(T0.minus(PhoneVerificationServiceImpl.CLAIM_WINDOW)));
    }

    @Test
    void claimAsksTheProviderOnceMoreWhenThePollHadNotYetSeenTheSms() {
        PhoneVerificationEntity r = row(PhoneVerificationStatus.PENDING, T0.plusSeconds(200));
        stored(r);
        when(gateway.status("vmn-1")).thenReturn(PhoneVerificationStatus.VERIFIED);
        when(verifications.tryClaim(eq(ID), eq(PHONE), eq(REGISTER), any())).thenReturn(1);

        service.claim(ID, PHONE, REGISTER);

        assertThat(r.getStatus()).isEqualTo(PhoneVerificationStatus.VERIFIED);
    }

    @Test
    void claimRefusesAnUnconfirmedOrAlreadyUsedCheck() {
        stored(row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200)));
        when(verifications.tryClaim(eq(ID), eq(PHONE), eq(REGISTER), any())).thenReturn(0);

        assertThatThrownBy(() -> service.claim(ID, PHONE, REGISTER))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
    }

    @Test
    void aCheckCannotRegisterAnotherPhone() {
        stored(row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200)));

        assertThatThrownBy(() -> service.claim(ID, "99000000", REGISTER))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        verify(verifications, never()).tryClaim(any(), any(), any(), any());
    }

    @Test
    void anUnknownIdCannotBeClaimed() {
        when(verifications.findById(ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.claim(ID, PHONE, REGISTER)).isInstanceOf(BadRequestException.class);
    }

    // ------- password reset ----------------------------------------------

    private void account(Role role) {
        UserEntity u = new UserEntity();
        u.setPhoneNumber(PHONE);
        u.setRole(role);
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.of(u));
    }

    @Test
    void aResetCheckIsOpenedForAViewersPhoneAndRemembersItsPurpose() {
        account(Role.VIEWER);
        when(codes.next()).thenReturn("482916");
        when(gateway.start(PHONE, "482916")).thenReturn(session());
        when(verifications.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.start(PHONE, RESET);

        ArgumentCaptor<PhoneVerificationEntity> saved = ArgumentCaptor.forClass(PhoneVerificationEntity.class);
        verify(verifications).save(saved.capture());
        assertThat(saved.getValue().getPurpose()).isEqualTo(RESET);
    }

    @Test
    void aResetForAPhoneWithoutAnAccountIs404BeforeTheUserPaysForAnSms() {
        when(users.findByPhoneNumber(PHONE)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.start(PHONE, RESET))
                .isInstanceOf(NotFoundException.class)
                .hasMessage(PhoneVerificationService.ACCOUNT_NOT_FOUND);
        verifyNoInteractions(gateway);
        verify(verifications, never()).save(any());
    }

    @Test
    void aResetForACompanyOrAdminPhoneIs404Too() {
        account(Role.COMPANY);

        assertThatThrownBy(() -> service.start(PHONE, RESET)).isInstanceOf(NotFoundException.class);
        verifyNoInteractions(gateway);
    }

    @Test
    void aRegisteredPhoneMayStartAResetEvenThoughItCannotRegisterAgain() {
        account(Role.VIEWER);
        when(users.existsByPhoneNumber(PHONE)).thenReturn(true);
        when(codes.next()).thenReturn("482916");
        when(gateway.start(PHONE, "482916")).thenReturn(session());
        when(verifications.save(any())).thenAnswer(inv -> inv.getArgument(0));

        assertThat(service.start(PHONE, RESET).verificationId()).isNotNull();
    }

    @Test
    void aCheckOpenedToRegisterCannotResetAPassword() {
        stored(row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200))); // purpose REGISTER

        assertThatThrownBy(() -> service.claim(ID, PHONE, RESET))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(VerifiedPhoneClaim.NOT_VERIFIED);
        verify(verifications, never()).tryClaim(any(), any(), any(), any());
    }

    @Test
    void aResetCheckIsClaimedForItsOwnPurpose() {
        PhoneVerificationEntity r = row(PhoneVerificationStatus.VERIFIED, T0.plusSeconds(200));
        r.setPurpose(RESET);
        stored(r);
        when(verifications.tryClaim(eq(ID), eq(PHONE), eq(RESET), any())).thenReturn(1);

        service.claim(ID, PHONE, RESET);

        verify(verifications).tryClaim(eq(ID), eq(PHONE), eq(RESET), any());
    }

    @Test
    void theClaimWindowIsLongerThanTheProvidersSessionLifetime() {
        assertThat(PhoneVerificationServiceImpl.CLAIM_WINDOW).isGreaterThan(Duration.ofMinutes(5));
    }
}
