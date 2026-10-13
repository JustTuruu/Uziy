package mn.uziy.backend.phoneverify;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * A freshly opened check. The app shows {@code displayInstruction} unchanged, offers {@code smsUri} as the main
 * button, polls with {@code verificationId}, and finally registers with it.
 */
public record PhoneVerificationStartedRes(
        UUID verificationId,
        String phoneNumber,
        String shortcode,
        String smsText,
        String smsUri,
        String displayInstruction,
        PhoneVerificationStatus status,
        OffsetDateTime expiresAt) {
}
