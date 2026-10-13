package mn.uziy.backend.phoneverify;

import java.util.UUID;

/** Registration's view of phone checks: spend a confirmed check exactly once. */
public interface VerifiedPhoneClaim {

    String NOT_VERIFIED = "Утасны дугаар баталгаажаагүй байна. Дахин оролдоно уу";

    /**
     * Uses up the check {@code verificationId} for {@code phoneNumber}. It must be confirmed, unused, for that
     * very phone, and confirmed recently.
     *
     * @throws mn.uziy.backend.common.BadRequestException with {@link #NOT_VERIFIED} otherwise
     */
    void claim(UUID verificationId, String phoneNumber);
}
