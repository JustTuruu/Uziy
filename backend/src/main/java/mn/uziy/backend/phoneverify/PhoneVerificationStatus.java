package mn.uziy.backend.phoneverify;

/** Where a phone check stands. Same names as verify.mn's {@code sessionStatus}, and part of our API contract. */
public enum PhoneVerificationStatus {
    /** Waiting for the user's SMS. */
    PENDING,
    /** The SMS arrived from the phone being checked. */
    VERIFIED,
    /** The time ran out before the SMS arrived; a new check (new code) is needed. */
    EXPIRED
}
