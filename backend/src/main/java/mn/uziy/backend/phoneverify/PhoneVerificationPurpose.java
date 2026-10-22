package mn.uziy.backend.phoneverify;

import java.time.Duration;

/**
 * Why a phone is being proved. A check is spent only for the purpose it was opened for, so a check made to
 * register can never reset a password or finish an admin login (or the other way round).
 */
public enum PhoneVerificationPurpose {
    /** A new viewer account: the phone must have no account yet. */
    REGISTER(Duration.ofMinutes(30)),
    /** A forgotten password: the phone must belong to a viewer. */
    PASSWORD_RESET(Duration.ofMinutes(30)),
    /**
     * The second step of an admin's login. Opened only by the login after a correct password, never through the
     * public endpoint, and short-lived: an unfinished login must not stay usable.
     */
    ADMIN_LOGIN(Duration.ofMinutes(5));

    private final Duration claimWindow;

    PhoneVerificationPurpose(Duration claimWindow) {
        this.claimWindow = claimWindow;
    }

    /** How long after the SMS a confirmed check can still be spent. */
    public Duration claimWindow() {
        return claimWindow;
    }
}
