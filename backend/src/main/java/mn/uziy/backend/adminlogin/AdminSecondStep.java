package mn.uziy.backend.adminlogin;

import mn.uziy.backend.domain.UserEntity;

/** The password login's view of the admin second step: after a correct password, open the phone check. */
public interface AdminSecondStep {

    /**
     * Opens the phone check that must be completed before {@code admin} receives a token.
     *
     * @throws mn.uziy.backend.common.TooManyRequestsException within the SMS cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    AdminLoginChallenge open(UserEntity admin);
}
