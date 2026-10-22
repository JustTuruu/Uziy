package mn.uziy.backend.trusteddevice;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import mn.uziy.backend.account.ViewerDeleted;
import mn.uziy.backend.passwordreset.PasswordReset;
import org.junit.jupiter.api.Test;

class TrustedDeviceCleanupTest {

    private final TrustedDeviceRevoker revoker = mock(TrustedDeviceRevoker.class);
    private final TrustedDeviceCleanup cleanup = new TrustedDeviceCleanup(revoker);

    @Test
    void aPasswordResetForgetsTheAccountsBrowsers() {
        cleanup.onPasswordReset(new PasswordReset(5L));

        verify(revoker).revokeAll(5L);
    }

    @Test
    void aDeletedAccountForgetsItsBrowsers() {
        cleanup.onViewerDeleted(new ViewerDeleted(9L));

        verify(revoker).revokeAll(9L);
    }
}
