package mn.uziy.backend.trusteddevice;

import mn.uziy.backend.account.ViewerDeleted;
import mn.uziy.backend.passwordreset.PasswordReset;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Pattern: Observer — a new password or a deleted account forgets every remembered browser, inside the same
 * transaction (events are delivered synchronously). The login query also refuses a browser trusted before the last
 * password change, so this is the tidy-up, not the only guard.
 */
@Component
public class TrustedDeviceCleanup {

    private final TrustedDeviceRevoker revoker;

    public TrustedDeviceCleanup(TrustedDeviceRevoker revoker) {
        this.revoker = revoker;
    }

    @EventListener
    public void onPasswordReset(PasswordReset event) {
        revoker.revokeAll(event.userId());
    }

    @EventListener
    public void onViewerDeleted(ViewerDeleted event) {
        revoker.revokeAll(event.viewerId());
    }
}
