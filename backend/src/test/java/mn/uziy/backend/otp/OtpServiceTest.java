package mn.uziy.backend.otp;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.TooManyRequestsException;
import mn.uziy.backend.common.UnavailableException;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

class OtpServiceTest {

    private static final String PHONE = "88112233";
    private static final Instant T0 = Instant.parse("2026-10-07T04:00:00Z");

    private final OtpCodeRepository codes = mock(OtpCodeRepository.class);
    private final OtpCodeGenerator generator = mock(OtpCodeGenerator.class);
    private final OtpSender sender = mock(OtpSender.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final Clock clock = Clock.fixed(T0, ZoneOffset.UTC);
    private final OtpServiceImpl service = new OtpServiceImpl(codes, generator, sender, encoder, clock);

    private static OffsetDateTime at(Instant i) {
        return OffsetDateTime.ofInstant(i, ZoneOffset.UTC);
    }

    private OtpCodeEntity stored(Instant created) {
        OtpCodeEntity row = new OtpCodeEntity();
        row.setPhoneNumber(PHONE);
        row.setPurpose(OtpPurpose.REGISTER);
        row.setCodeHash("hash");
        row.setCreatedAt(at(created));
        row.setExpiresAt(at(created.plus(OtpServiceImpl.TTL)));
        return row;
    }

    private void latestIs(OtpCodeEntity row) {
        when(codes.findFirstByPhoneNumberAndPurposeOrderByCreatedAtDesc(PHONE, OtpPurpose.REGISTER))
                .thenReturn(Optional.ofNullable(row));
    }

    // ------- issue ---------------------------------------------------------

    @Test
    void issueStoresOnlyTheHashAndSendsThePlainCode() {
        latestIs(null);
        when(generator.next()).thenReturn("482913");
        when(encoder.encode("482913")).thenReturn("hash-of-code");

        service.issue(PHONE, OtpPurpose.REGISTER);

        ArgumentCaptor<OtpCodeEntity> row = ArgumentCaptor.forClass(OtpCodeEntity.class);
        verify(codes).save(row.capture());
        assertThat(row.getValue().getCodeHash()).isEqualTo("hash-of-code");
        assertThat(row.getValue().getPhoneNumber()).isEqualTo(PHONE);
        assertThat(row.getValue().getPurpose()).isEqualTo(OtpPurpose.REGISTER);
        assertThat(row.getValue().getCreatedAt()).isEqualTo(at(T0));
        assertThat(row.getValue().getExpiresAt()).isEqualTo(at(T0.plus(OtpServiceImpl.TTL)));
        verify(sender).send(PHONE, "482913", OtpPurpose.REGISTER);
    }

    @Test
    void issueWithinTheCooldownIsRefusedAndSendsNothing() {
        latestIs(stored(T0.minusSeconds(OtpServiceImpl.COOLDOWN.getSeconds() - 1)));

        assertThatThrownBy(() -> service.issue(PHONE, OtpPurpose.REGISTER))
                .isInstanceOf(TooManyRequestsException.class)
                .hasMessage(OtpService.TOO_SOON);
        verify(sender, never()).send(any(), any(), any());
        verify(codes, never()).save(any());
    }

    @Test
    void issueRightAfterTheCooldownIsAllowed() {
        latestIs(stored(T0.minus(OtpServiceImpl.COOLDOWN)));
        when(generator.next()).thenReturn("111111");

        service.issue(PHONE, OtpPurpose.REGISTER);

        verify(sender).send(PHONE, "111111", OtpPurpose.REGISTER);
    }

    @Test
    void issueBeyondTheHourlyLimitIsRefused() {
        latestIs(null);
        when(codes.countByPhoneNumberAndPurposeAndCreatedAtAfter(
                eq(PHONE), eq(OtpPurpose.REGISTER), eq(at(T0.minus(OtpServiceImpl.HOURLY_WINDOW)))))
                .thenReturn((long) OtpServiceImpl.MAX_PER_HOUR);

        assertThatThrownBy(() -> service.issue(PHONE, OtpPurpose.REGISTER))
                .isInstanceOf(TooManyRequestsException.class)
                .hasMessage(OtpService.TOO_MANY);
        verify(sender, never()).send(any(), any(), any());
    }

    @Test
    void aFailingSenderBecomesServiceUnavailable() {
        latestIs(null);
        when(generator.next()).thenReturn("123456");
        doThrow(new IllegalStateException("gateway down")).when(sender).send(any(), any(), any());

        assertThatThrownBy(() -> service.issue(PHONE, OtpPurpose.REGISTER))
                .isInstanceOf(UnavailableException.class)
                .hasMessage(OtpService.SEND_FAILED);
    }

    // ------- verifyAndConsume ----------------------------------------------

    @Test
    void theRightCodeIsAcceptedAndUsedUp() {
        OtpCodeEntity row = stored(T0.minusSeconds(30));
        latestIs(row);
        when(encoder.matches("123456", "hash")).thenReturn(true);

        service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "123456");

        assertThat(row.isConsumed()).isTrue();
        verify(codes).save(row);
    }

    @Test
    void aWrongCodeIsRejectedAndCounted() {
        OtpCodeEntity row = stored(T0.minusSeconds(30));
        latestIs(row);
        when(encoder.matches("000000", "hash")).thenReturn(false);

        assertThatThrownBy(() -> service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "000000"))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(OtpService.INVALID_CODE);
        assertThat(row.getAttempts()).isEqualTo(1);
        assertThat(row.isConsumed()).isFalse();
        verify(codes).save(row);
    }

    @Test
    void afterTheAttemptLimitEvenTheRightCodeIsRefused() {
        OtpCodeEntity row = stored(T0.minusSeconds(30));
        row.setAttempts(OtpServiceImpl.MAX_ATTEMPTS);
        latestIs(row);
        when(encoder.matches("123456", "hash")).thenReturn(true);

        assertThatThrownBy(() -> service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "123456"))
                .isInstanceOf(BadRequestException.class);
        assertThat(row.isConsumed()).isFalse();
    }

    @Test
    void anExpiredCodeIsRefused() {
        latestIs(stored(T0.minus(OtpServiceImpl.TTL).minusSeconds(1)));
        when(encoder.matches("123456", "hash")).thenReturn(true);

        assertThatThrownBy(() -> service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "123456"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void aCodeCannotBeUsedTwice() {
        OtpCodeEntity row = stored(T0.minusSeconds(30));
        row.setConsumed(true);
        latestIs(row);
        when(encoder.matches("123456", "hash")).thenReturn(true);

        assertThatThrownBy(() -> service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "123456"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void withoutAnyIssuedCodeNothingIsAccepted() {
        latestIs(null);

        assertThatThrownBy(() -> service.verifyAndConsume(PHONE, OtpPurpose.REGISTER, "123456"))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(OtpService.INVALID_CODE);
        verify(encoder, never()).matches(any(), any());
    }
}
