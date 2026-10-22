package mn.uziy.backend.trusteddevice;

import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: {@code POST /admin/users/{id}/trusted-devices/forget} → 204 (404 for an unknown account). */
@RestController
@RequestMapping("/admin/users")
@PreAuthorize("hasRole('ADMIN')")
public class TrustedDeviceAdminController {

    private final TrustedDeviceAdminService devices;

    public TrustedDeviceAdminController(TrustedDeviceAdminService devices) {
        this.devices = devices;
    }

    @PostMapping("/{id}/trusted-devices/forget")
    public ResponseEntity<Void> forget(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        devices.forgetAll(id, principal.userId());
        return ResponseEntity.noContent().build();
    }
}
