package mn.uziy.backend.consolelogin;

import mn.uziy.backend.common.Masking;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.phoneverify.PhoneVerificationStartedRes;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — an opened phone check to the console login's second-step answer (phone masked). */
@Component
public class ConsoleLoginMapper {

    public ConsoleLoginChallenge toChallenge(PhoneVerificationStartedRes check, Role role) {
        return new ConsoleLoginChallenge(new ConsoleLoginChallenge.TwoStep(
                check.verificationId(),
                Masking.lastFour(check.phoneNumber()),
                role,
                check.shortcode(),
                check.smsText(),
                check.smsUri(),
                check.displayInstruction(),
                check.expiresAt()));
    }
}
