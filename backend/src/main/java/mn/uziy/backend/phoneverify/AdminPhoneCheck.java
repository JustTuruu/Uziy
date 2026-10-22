package mn.uziy.backend.phoneverify;

/**
 * The admin login's view of phone checks: open the second step once the password is proved. Kept apart from
 * {@link PhoneVerificationService} because only the login may open an {@code ADMIN_LOGIN} check.
 */
public interface AdminPhoneCheck {

    /**
     * Opens an {@link PhoneVerificationPurpose#ADMIN_LOGIN} check of {@code phoneNumber}. The caller must already
     * have proved the admin's password.
     *
     * @throws mn.uziy.backend.common.TooManyRequestsException within the cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    PhoneVerificationStartedRes openForAdminLogin(String phoneNumber);
}
