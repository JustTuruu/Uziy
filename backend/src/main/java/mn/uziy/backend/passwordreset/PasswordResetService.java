package mn.uziy.backend.passwordreset;

/** Sets a new password for a viewer who proved, by texting a code from it, that they hold the phone. */
public interface PasswordResetService {

    /**
     * Spends the phone check and stores the new password, in one transaction.
     *
     * @throws mn.uziy.backend.common.BadRequestException when the check is not a confirmed, unused password-reset
     *         check of that phone, or the phone has no viewer account
     */
    void reset(ResetPasswordReq req);
}
