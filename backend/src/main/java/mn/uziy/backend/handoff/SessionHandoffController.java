package mn.uziy.backend.handoff;

import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP adapter: the company login page asks for a code with the admin's fresh token ({@code 201}); the admin panel
 * spends it for its own session ({@code 200}, or {@code 400} with one sentence).
 */
@RestController
public class SessionHandoffController {

    private final SessionHandoffService handoffs;

    public SessionHandoffController(SessionHandoffService handoffs) {
        this.handoffs = handoffs;
    }

    @PostMapping("/admin/session-handoffs")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<HandoffCode> create(@Auth JwtPrincipal principal) {
        return ResponseEntity.status(HttpStatus.CREATED).body(handoffs.create(principal.userId()));
    }

    @PostMapping("/auth/session-handoffs/redeem")
    public AuthResponse redeem(@RequestBody RedeemHandoffReq body) {
        return handoffs.redeem(body.code());
    }
}
