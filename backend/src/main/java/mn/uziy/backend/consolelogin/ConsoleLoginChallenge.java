package mn.uziy.backend.consolelogin;

import java.time.OffsetDateTime;
import java.util.UUID;
import mn.uziy.backend.domain.Role;

/**
 * What {@code POST /auth/login} answers (202) an admin or a company whose password was right on a browser the
 * server does not recognise: no token yet, only the SMS to send. The panel shows {@code twoStep.displayInstruction}
 * unchanged, offers {@code smsUri}, polls {@code GET /auth/phone-verifications/{verificationId}} and finishes with
 * {@code POST /auth/login/verify}.
 */
public record ConsoleLoginChallenge(TwoStep twoStep) {

    /**
     * {@code phoneNumber} is masked ({@code •••• 2233}); the panel already knows the number it typed. {@code role}
     * lets a panel turn away the other console's account before anybody pays for an SMS (the password is proved).
     */
    public record TwoStep(
            UUID verificationId,
            String phoneNumber,
            Role role,
            String shortcode,
            String smsText,
            String smsUri,
            String displayInstruction,
            OffsetDateTime expiresAt) {
    }
}
