package mn.uziy.backend.adminlogin;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * What {@code POST /auth/login} answers an admin whose password was right: no token yet, only the SMS to send.
 * The panel shows {@code twoStep.displayInstruction} unchanged, offers {@code smsUri}, polls
 * {@code GET /auth/phone-verifications/{verificationId}} and finishes with {@code POST /auth/admin/login/verify}.
 */
public record AdminLoginChallenge(TwoStep twoStep) {

    /** {@code phoneNumber} is masked ({@code •••• 2233}); the panel already knows the number it typed. */
    public record TwoStep(
            UUID verificationId,
            String phoneNumber,
            String shortcode,
            String smsText,
            String smsUri,
            String displayInstruction,
            OffsetDateTime expiresAt) {
    }
}
