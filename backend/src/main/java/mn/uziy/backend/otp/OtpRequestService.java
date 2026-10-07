package mn.uziy.backend.otp;

/** Account-aware entry point for asking for a code. */
public interface OtpRequestService {

    /**
     * REGISTER: refuses a phone that already has an account (409). PASSWORD_RESET: sends only to an
     * existing viewer and otherwise does nothing, silently, so the answer never reveals who is
     * registered.
     */
    void requestCode(String phoneNumber, OtpPurpose purpose);
}
