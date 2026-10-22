package mn.uziy.backend.consolelogin;

import java.time.OffsetDateTime;
import mn.uziy.backend.auth.Me;

/**
 * The usual {@code {token, user}} plus this browser's secret: sent back as {@code deviceToken} with the next logins,
 * it skips the SMS until {@code deviceTrustedUntil}. It is handed out only here, once.
 */
public record ConsoleLoginVerifiedRes(String token, Me user, String deviceToken, OffsetDateTime deviceTrustedUntil) {

    /** Never print the token or the device secret. */
    @Override
    public String toString() {
        return "ConsoleLoginVerifiedRes[userId=" + user.id() + ", deviceTrustedUntil=" + deviceTrustedUntil + "]";
    }
}
