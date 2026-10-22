package mn.uziy.backend.trusteddevice;

import java.time.OffsetDateTime;

/** A browser just trusted: its secret (handed out once, never stored) and when the trust runs out. */
public record IssuedDevice(String secret, OffsetDateTime trustedUntil) {

    /** Never print the secret (audit 2026-10-22: no tokens in logs). */
    @Override
    public String toString() {
        return "IssuedDevice[trustedUntil=" + trustedUntil + "]";
    }
}
