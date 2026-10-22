package mn.uziy.backend.consolelogin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.util.UUID;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.phoneverify.PhoneVerificationStartedRes;
import mn.uziy.backend.phoneverify.PhoneVerificationStatus;
import org.junit.jupiter.api.Test;

class ConsoleLoginMapperTest {

    @Test
    void copiesTheSmsInstructionsNamesTheRoleAndMasksThePhone() {
        UUID id = UUID.randomUUID();
        OffsetDateTime expires = OffsetDateTime.parse("2026-10-22T04:05:00Z");
        PhoneVerificationStartedRes check = new PhoneVerificationStartedRes(id, "99001122", "144773", "482916",
                "sms:144773?body=482916", "Та 99001122 дугаараас SMS илгээнэ үү", PhoneVerificationStatus.PENDING,
                expires);

        ConsoleLoginChallenge challenge = new ConsoleLoginMapper().toChallenge(check, Role.COMPANY);

        assertThat(challenge.twoStep()).isEqualTo(new ConsoleLoginChallenge.TwoStep(id, "•••• 1122", Role.COMPANY,
                "144773", "482916", "sms:144773?body=482916", "Та 99001122 дугаараас SMS илгээнэ үү", expires));
    }
}
