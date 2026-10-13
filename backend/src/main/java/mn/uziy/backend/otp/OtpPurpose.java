package mn.uziy.backend.otp;

/**
 * Why a one-time code was issued; a code only works for the purpose it was sent for. Registration does not use
 * these codes: it proves the phone through {@code phoneverify} (the user texts verify.mn).
 */
public enum OtpPurpose {
    PASSWORD_RESET
}
