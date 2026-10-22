package mn.uziy.backend.trusteddevice;

/** The admin's action on another account's remembered browsers. */
public interface TrustedDeviceAdminService {

    /**
     * Forgets every browser of {@code userId}: its next login asks for the SMS again. Signed-in sessions are not
     * ended (their tokens are still valid until they expire or the password changes).
     *
     * @throws mn.uziy.backend.common.NotFoundException when there is no such account
     */
    void forgetAll(long userId, long adminId);
}
