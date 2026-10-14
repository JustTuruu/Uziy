package mn.uziy.backend.phoneverify;

/**
 * Why a phone is being proved. A check is spent only for the purpose it was opened for, so a check made to
 * register can never reset a password (or the other way round).
 */
public enum PhoneVerificationPurpose {
    /** A new viewer account: the phone must have no account yet. */
    REGISTER,
    /** A forgotten password: the phone must belong to a viewer. */
    PASSWORD_RESET
}
