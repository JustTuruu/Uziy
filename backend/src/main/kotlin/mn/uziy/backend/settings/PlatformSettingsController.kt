package mn.uziy.backend.settings

import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*

@RestController
class PlatformSettingsController(private val settings: PlatformSettingsService) {

    /**
     * Public read — the company wizard needs the commission and the minimum
     * reward to preview pricing before the campaign is created. Contains no
     * sensitive data.
     */
    @GetMapping("/platform-settings")
    fun get(): PlatformSettingsDto = settings.get()

    @PatchMapping("/admin/platform-settings")
    @PreAuthorize("hasRole('ADMIN')")
    fun update(
        @RequestBody body: UpdatePlatformSettingsReq,
        @Auth admin: JwtPrincipal,
    ): PlatformSettingsDto = settings.update(body, admin.userId)
}
