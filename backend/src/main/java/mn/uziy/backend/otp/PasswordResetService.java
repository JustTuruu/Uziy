package mn.uziy.backend.otp;

/** Sets a new password for a viewer who proves, with a code, that they hold the phone. */
public interface PasswordResetService {

    /** @throws mn.uziy.backend.common.BadRequestException when the code is wrong or the phone has no viewer */
    void reset(ResetPasswordReq req);
}
