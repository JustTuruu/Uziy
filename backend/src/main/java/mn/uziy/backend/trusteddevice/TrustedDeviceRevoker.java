package mn.uziy.backend.trusteddevice;

/** Forgetting remembered browsers: after a password reset, an account deletion, or at an admin's request. */
public interface TrustedDeviceRevoker {

    /** Forgets every browser of {@code userId}; returns how many there were. */
    int revokeAll(long userId);
}
