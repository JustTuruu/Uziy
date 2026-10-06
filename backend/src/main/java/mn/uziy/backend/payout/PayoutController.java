package mn.uziy.backend.payout;

import jakarta.validation.Valid;
import java.util.List;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.jspecify.annotations.Nullable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for payouts — the viewer's requests and the admin's decisions. */
@RestController
public class PayoutController {

    private final PayoutRequestService viewerPayouts;
    private final PayoutReviewService adminPayouts;

    public PayoutController(PayoutRequestService viewerPayouts, PayoutReviewService adminPayouts) {
        this.viewerPayouts = viewerPayouts;
        this.adminPayouts = adminPayouts;
    }

    // --- Viewer side ---------------------------------------------------------

    @PostMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    public PayoutDto request(@Valid @RequestBody CreatePayoutReq body, @Auth JwtPrincipal principal) {
        return viewerPayouts.request(principal.userId(), body);
    }

    @GetMapping("/viewer/payouts")
    @PreAuthorize("hasRole('VIEWER')")
    public List<PayoutDto> mine(@Auth JwtPrincipal principal) {
        return viewerPayouts.mine(principal.userId());
    }

    // --- Admin side ----------------------------------------------------------

    @GetMapping("/admin/payouts")
    @PreAuthorize("hasRole('ADMIN')")
    public List<PayoutDto> pending() {
        return adminPayouts.pending();
    }

    @GetMapping("/admin/payouts/history")
    @PreAuthorize("hasRole('ADMIN')")
    public List<PayoutDto> history() {
        return adminPayouts.history();
    }

    @PatchMapping("/admin/payouts/{id}/decision")
    @PreAuthorize("hasRole('ADMIN')")
    public PayoutDto decide(
            @PathVariable("id") long id,
            @RequestParam("decision") PayoutStatus decision,
            @RequestParam(name = "reason", required = false) @Nullable String reason,
            @Auth JwtPrincipal principal) {
        return adminPayouts.decide(id, decision, reason, principal.userId());
    }
}
