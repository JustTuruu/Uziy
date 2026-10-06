package mn.uziy.backend.settings;

import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PlatformSettingsController {

    private final PlatformSettingsService settings;

    public PlatformSettingsController(PlatformSettingsService settings) {
        this.settings = settings;
    }

    /**
     * Public read — the company wizard needs the commission and the minimum
     * reward to preview pricing before the campaign is created. Contains no
     * sensitive data.
     */
    @GetMapping("/platform-settings")
    public PlatformSettingsDto get() {
        return settings.get();
    }

    @PatchMapping("/admin/platform-settings")
    @PreAuthorize("hasRole('ADMIN')")
    public PlatformSettingsDto update(@RequestBody UpdatePlatformSettingsReq body, @Auth JwtPrincipal admin) {
        return settings.update(body, admin.userId());
    }
}
