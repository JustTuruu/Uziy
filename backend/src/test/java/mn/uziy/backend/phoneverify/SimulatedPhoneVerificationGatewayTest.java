package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class SimulatedPhoneVerificationGatewayTest {

    private static final Instant T0 = Instant.parse("2026-10-13T04:00:00Z");

    private final SimulatedPhoneVerificationGateway gateway =
            new SimulatedPhoneVerificationGateway(Clock.fixed(T0, ZoneOffset.UTC));

    @Test
    void startDescribesTheSmsLikeTheRealProvider() {
        PhoneVerificationSession s = gateway.start("88112233", "482916");

        assertThat(s.sessionId()).isNotBlank();
        assertThat(s.text()).isEqualTo("482916");
        assertThat(s.smsUri()).isEqualTo("sms:144773?body=482916");
        assertThat(s.displayInstruction()).contains("88112233").contains("144773").contains("482916");
        assertThat(s.expiresAt()).isEqualTo(OffsetDateTime.ofInstant(T0, ZoneOffset.UTC)
                .plus(SimulatedPhoneVerificationGateway.TTL));
    }

    @Test
    void aNewSessionStaysPendingUntilItsSmsArrives() {
        String id = gateway.start("88112233", "482916").sessionId();

        assertThat(gateway.status(id)).isEqualTo(PhoneVerificationStatus.PENDING);
        assertThat(gateway.status(id)).as("polling alone never verifies").isEqualTo(PhoneVerificationStatus.PENDING);

        assertThat(gateway.receiveSms(id)).isTrue();
        assertThat(gateway.status(id)).isEqualTo(PhoneVerificationStatus.VERIFIED);
    }

    @Test
    void theSmsOfOneSessionDoesNotVerifyAnother() {
        String a = gateway.start("88112233", "1").sessionId();
        String b = gateway.start("88112234", "2").sessionId();

        gateway.receiveSms(a);

        assertThat(gateway.status(b)).isEqualTo(PhoneVerificationStatus.PENDING);
    }

    @Test
    void anUnknownSessionIsExpiredAndCannotReceiveAnSms() {
        assertThat(gateway.status("never-opened")).isEqualTo(PhoneVerificationStatus.EXPIRED);
        assertThat(gateway.receiveSms("never-opened")).isFalse();
        assertThat(gateway.status("never-opened")).isEqualTo(PhoneVerificationStatus.EXPIRED);
    }

    @Test
    void sessionIdsAreUnique() {
        assertThat(gateway.start("88112233", "1").sessionId()).isNotEqualTo(gateway.start("88112233", "1").sessionId());
    }
}
