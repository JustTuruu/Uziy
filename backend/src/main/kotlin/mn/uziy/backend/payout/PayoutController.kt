package mn.uziy.backend.payout

import jakarta.validation.Valid
import mn.uziy.backend.domain.PayoutStatus
import mn.uziy.backend.security.Auth
import mn.uziy.backend.security.JwtPrincipal
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*

/** HTTP adapter for payouts — the viewer's requests and the admin's decisions. */
@RestController
class PayoutController(private val payouts: PayoutService) {

    // --- Viewer side ---------------------------------------------------------

    @PostMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    fun request(
        @Valid @RequestBody body: CreatePayoutReq,
        @Auth principal: JwtPrincipal,
    ): PayoutDto = payouts.request(principal.userId, body)

    @GetMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    fun mine(@Auth principal: JwtPrincipal): List<PayoutDto> = payouts.mine(principal.userId)

    // --- Admin side ----------------------------------------------------------

    @GetMapping("/admin/payouts")
    @PreAuthorize("hasRole('ADMIN')")
    fun pending(): List<PayoutDto> = payouts.pending()

    @GetMapping("/admin/payouts/history")
    @PreAuthorize("hasRole('ADMIN')")
    fun history(): List<PayoutDto> = payouts.history()

    @PatchMapping("/admin/payouts/{id}/decision")
    @PreAuthorize("hasRole('ADMIN')")
    fun decide(
        @PathVariable id: Long,
        @RequestParam decision: PayoutStatus,
        @RequestParam(required = false) reason: String?,
        @Auth principal: JwtPrincipal,
    ): PayoutDto = payouts.decide(id, decision, reason, principal.userId)
}
