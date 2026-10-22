package mn.uziy.backend.trusteddevice;

import org.jspecify.annotations.Nullable;

/** The console login's view of remembered browsers: is this one known, and remember this one. */
public interface DeviceTrust {

    /**
     * True when {@code secret} belongs to a browser {@code userId} proved its phone from, which has not run out and
     * was trusted after the last password change; the browser's last use is then set to now. Anything else
     * (missing, garbage, another account's, expired, older than a password change) is simply false.
     */
    boolean recognises(long userId, @Nullable String secret);

    /**
     * Remembers a new browser for {@code userId} and returns its secret. Keeps at most
     * {@link TrustedDeviceServiceImpl#MAX_DEVICES_PER_USER}: the ones used least recently are forgotten.
     */
    IssuedDevice trust(long userId, @Nullable String userAgent);
}
