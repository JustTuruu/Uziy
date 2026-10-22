package mn.uziy.backend.adminlogin;

import mn.uziy.backend.auth.AuthResponse;

/** Finishes an admin's login once the phone check opened by the password step is confirmed. */
public interface AdminLoginService {

    /**
     * Spends the {@code ADMIN_LOGIN} check {@code req.verificationId()} of {@code req.phoneNumber()} and signs the
     * admin in.
     *
     * @throws mn.uziy.backend.common.BadRequestException when the check is not confirmed, already used, too old,
     *         made for something else or for another phone, or the phone is not an admin's
     * @throws mn.uziy.backend.common.TooManyRequestsException while the phone is locked by failed attempts
     */
    AuthResponse verify(AdminLoginVerifyReq req);
}
