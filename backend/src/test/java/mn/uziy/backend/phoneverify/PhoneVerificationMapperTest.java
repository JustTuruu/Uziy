package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PhoneVerificationMapperTest {

    private final PhoneVerificationMapper mapper = new PhoneVerificationMapper();
    private final OffsetDateTime expires = OffsetDateTime.parse("2026-10-13T04:05:00Z");

    private PhoneVerificationEntity row() {
        PhoneVerificationEntity r = new PhoneVerificationEntity();
        r.setId(UUID.fromString("11111111-2222-3333-4444-555555555555"));
        r.setPhoneNumber("88112233");
        r.setStatus(PhoneVerificationStatus.PENDING);
        r.setExpiresAt(expires);
        return r;
    }

    @Test
    void startedCombinesOurIdWithTheProvidersInstructionsButNotItsSessionId() {
        var session = new PhoneVerificationSession("provider-secret-id", "144773", "482916",
                "sms:144773?body=482916", "instruction", expires);

        PhoneVerificationStartedRes res = mapper.toStarted(row(), session);

        assertThat(res).isEqualTo(new PhoneVerificationStartedRes(row().getId(), "88112233", "144773", "482916",
                "sms:144773?body=482916", "instruction", PhoneVerificationStatus.PENDING, expires));
        assertThat(res.toString()).doesNotContain("provider-secret-id");
    }

    @Test
    void stateCarriesIdStatusAndExpiry() {
        assertThat(mapper.toState(row())).isEqualTo(
                new PhoneVerificationStateRes(row().getId(), PhoneVerificationStatus.PENDING, expires));
    }
}
