package mn.uziy.backend.adminlogin;

import mn.uziy.backend.common.Masking;
import mn.uziy.backend.phoneverify.PhoneVerificationStartedRes;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — an opened phone check to the admin login's second-step answer (phone masked). */
@Component
public class AdminLoginMapper {

    public AdminLoginChallenge toChallenge(PhoneVerificationStartedRes check) {
        return new AdminLoginChallenge(new AdminLoginChallenge.TwoStep(
                check.verificationId(),
                Masking.lastFour(check.phoneNumber()),
                check.shortcode(),
                check.smsText(),
                check.smsUri(),
                check.displayInstruction(),
                check.expiresAt()));
    }
}
