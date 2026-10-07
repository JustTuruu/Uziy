package mn.uziy.backend.otp;

/** Why a one-time code was issued; a code only works for the purpose it was sent for. */
public enum OtpPurpose {
    REGISTER,
    PASSWORD_RESET
}
