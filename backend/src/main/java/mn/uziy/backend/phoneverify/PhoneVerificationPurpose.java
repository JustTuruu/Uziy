package mn.uziy.backend.phoneverify;

import java.time.Duration;
import java.util.Optional;
import mn.uziy.backend.domain.Role;

/**
 * Why a phone is being proved. A check is spent only for the purpose it was opened for, so a check made to
 * register can never reset a password or finish a console login (or the other way round), and a company's login
 * check can never finish an admin's.
 */
public enum PhoneVerificationPurpose {
    /** A new viewer account: the phone must have no account yet. */
    REGISTER(Duration.ofMinutes(30), false),
    /** A forgotten password: the phone must belong to a viewer. */
    PASSWORD_RESET(Duration.ofMinutes(30), false),
    /**
     * The second step of an admin's login from a browser the server does not recognise. Opened only by the login
     * after a correct password, never through the public endpoint, and short-lived: an unfinished login must not
     * stay usable.
     */
    ADMIN_LOGIN(Duration.ofMinutes(5), true),
    /** The same second step for a company account (owner, 2026-10-22). */
    COMPANY_LOGIN(Duration.ofMinutes(5), true);

    private final Duration claimWindow;
    private final boolean loginStep;

    PhoneVerificationPurpose(Duration claimWindow, boolean loginStep) {
        this.claimWindow = claimWindow;
        this.loginStep = loginStep;
    }

    /** How long after the SMS a confirmed check can still be spent. */
    public Duration claimWindow() {
        return claimWindow;
    }

    /** True for a console login's second step: only the login itself may open such a check. */
    public boolean isLoginStep() {
        return loginStep;
    }

    /** The login-step purpose of a console account ({@code ADMIN}, {@code COMPANY}); empty for a viewer. */
    public static Optional<PhoneVerificationPurpose> loginStepFor(Role role) {
        return switch (role) {
            case ADMIN -> Optional.of(ADMIN_LOGIN);
            case COMPANY -> Optional.of(COMPANY_LOGIN);
            case VIEWER -> Optional.empty();
        };
    }
}
