package mn.uziy.backend.phoneverify;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PhoneVerificationStateRes(UUID verificationId, PhoneVerificationStatus status, OffsetDateTime expiresAt) {
}
