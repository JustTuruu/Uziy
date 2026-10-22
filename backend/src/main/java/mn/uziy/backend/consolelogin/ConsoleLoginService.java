package mn.uziy.backend.consolelogin;

import org.jspecify.annotations.Nullable;

/** Finishes a console login once the phone check opened by the password step is confirmed. */
public interface ConsoleLoginService {

    /**
     * Spends the login-step check {@code req.verificationId()} of {@code req.phoneNumber()}, signs the account in and
     * remembers this browser ({@code userAgent} only gives it a label).
     *
     * @throws mn.uziy.backend.common.BadRequestException when the check is not confirmed, already used, too old,
     *         made for something else, for another phone or for another role, or the phone has no console account
     * @throws mn.uziy.backend.common.TooManyRequestsException while the phone is locked by failed attempts
     */
    ConsoleLoginVerifiedRes verify(ConsoleLoginVerifyReq req, @Nullable String userAgent);
}
