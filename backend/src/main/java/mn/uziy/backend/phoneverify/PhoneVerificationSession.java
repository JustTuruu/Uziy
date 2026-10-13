package mn.uziy.backend.phoneverify;

import java.time.OffsetDateTime;

/**
 * A check the provider has opened: the user must send {@code text} to {@code shortcode} from the phone
 * being checked. {@code smsUri} opens the SMS app pre-filled; {@code displayInstruction} is the provider's
 * own wording and must be shown to the user unchanged (it names the phone to send from).
 */
public record PhoneVerificationSession(
        String sessionId,
        String shortcode,
        String text,
        String smsUri,
        String displayInstruction,
        OffsetDateTime expiresAt) {
}
