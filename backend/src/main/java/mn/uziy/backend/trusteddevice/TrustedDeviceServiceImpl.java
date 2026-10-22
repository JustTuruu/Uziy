package mn.uziy.backend.trusteddevice;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.regex.Pattern;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * "Ask for the phone only on a browser we do not know" (owner, 2026-10-22). After a console account proves its
 * phone, the browser gets a random secret; the next logins from it with the right password skip the SMS for
 * {@link #TRUST_PERIOD}. The password is still required every time — the secret only replaces the SMS step.
 */
@Service
public class TrustedDeviceServiceImpl implements DeviceTrust, TrustedDeviceRevoker {

    /** How long a browser stays recognised after its SMS. */
    public static final Duration TRUST_PERIOD = Duration.ofDays(30);
    /** Browsers remembered per account; beyond this the least recently used one is forgotten. */
    public static final int MAX_DEVICES_PER_USER = 10;
    /** The alphabet {@link DeviceSecrets#next()} writes in; anything else is not one of ours. */
    private static final Pattern SECRET_SHAPE = Pattern.compile("[A-Za-z0-9_-]+");

    private final TrustedDeviceRepository devices;
    private final DeviceSecrets secrets;
    private final Clock clock;

    public TrustedDeviceServiceImpl(TrustedDeviceRepository devices, DeviceSecrets secrets, Clock clock) {
        this.devices = devices;
        this.secrets = secrets;
        this.clock = clock;
    }

    @Override
    @Transactional
    public boolean recognises(long userId, @Nullable String secret) {
        if (!wellFormed(secret)) {
            return false;
        }
        return devices.touchIfTrusted(DeviceSecrets.hash(secret), userId, OffsetDateTime.now(clock)) == 1;
    }

    @Override
    @Transactional
    public IssuedDevice trust(long userId, @Nullable String userAgent) {
        String secret = secrets.next();
        OffsetDateTime now = OffsetDateTime.now(clock);
        TrustedDeviceEntity row = new TrustedDeviceEntity();
        row.setUserId(userId);
        row.setTokenHash(DeviceSecrets.hash(secret));
        row.setLabel(BrowserFamily.of(userAgent).orElse(null));
        row.setCreatedAt(now);
        row.setLastUsedAt(now);
        row.setExpiresAt(now.plus(TRUST_PERIOD));
        devices.save(row);
        devices.evictBeyond(userId, MAX_DEVICES_PER_USER, now);
        return new IssuedDevice(secret, row.getExpiresAt());
    }

    @Override
    @Transactional
    public int revokeAll(long userId) {
        return devices.deleteAllOfUser(userId);
    }

    private static boolean wellFormed(@Nullable String secret) {
        return secret != null
                && secret.length() <= DeviceSecrets.MAX_SECRET_LENGTH
                && SECRET_SHAPE.matcher(secret).matches();
    }
}
