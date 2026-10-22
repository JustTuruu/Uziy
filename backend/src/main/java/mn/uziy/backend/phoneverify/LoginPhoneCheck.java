package mn.uziy.backend.phoneverify;

/**
 * The console login's view of phone checks: open the second step once the password is proved. Kept apart from
 * {@link PhoneVerificationService} because only the login may open a login-step check.
 */
public interface LoginPhoneCheck {

    /**
     * Opens a check of {@code phoneNumber} for the login-step {@code purpose} ({@code ADMIN_LOGIN} or
     * {@code COMPANY_LOGIN}). The caller must already have proved the account's password.
     *
     * @throws IllegalArgumentException when {@code purpose} is not a login step (a programming error)
     * @throws mn.uziy.backend.common.TooManyRequestsException within the cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    PhoneVerificationStartedRes openForLogin(String phoneNumber, PhoneVerificationPurpose purpose);
}
