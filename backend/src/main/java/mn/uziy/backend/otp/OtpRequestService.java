package mn.uziy.backend.otp;

/** Account-aware entry point for asking for a code. */
public interface OtpRequestService {

    /**
     * PASSWORD_RESET: sends only to an existing viewer and otherwise does nothing, silently, so the answer never
     * reveals who is registered.
     */
    void requestCode(String phoneNumber, OtpPurpose purpose);
}
