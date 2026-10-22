package mn.uziy.backend.consolelogin;

import mn.uziy.backend.auth.LoginOutcome;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import org.jspecify.annotations.Nullable;

/** The password login's view of the console step: after a correct password, decide whether the phone is asked. */
public interface ConsoleLoginGate {

    /** True for the console roles (ADMIN, COMPANY); a viewer is signed in by the password alone. */
    boolean appliesTo(Role role);

    /**
     * {@code user}'s password was right. From a browser it proved its phone from ({@code deviceToken}) the user is
     * signed in; from anywhere else a phone check is opened and returned as the second step.
     *
     * @throws IllegalArgumentException for a role {@link #appliesTo} refuses (a programming error)
     * @throws mn.uziy.backend.common.TooManyRequestsException within the SMS cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    LoginOutcome afterPassword(UserEntity user, @Nullable String deviceToken);
}
