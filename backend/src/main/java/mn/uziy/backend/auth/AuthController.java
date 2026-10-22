package mn.uziy.backend.auth;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP adapter only — credential checking and account creation live in {@link AuthService}. Company accounts are
 * created by an admin ({@code POST /admin/companies}); there is no company self-registration.
 */
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    /**
     * Viewers: 200 with {@link AuthResponse}. Admins and companies with the right password: 200 as well when the
     * request carries the {@code deviceToken} of a browser they proved their phone from; otherwise <b>202
     * Accepted</b> with {@code {"twoStep": {...}}} and no token — the phone must still be proved, see
     * {@code mn.uziy.backend.consolelogin.ConsoleLoginController}. A wrong password: 401.
     */
    @PostMapping("/login")
    public ResponseEntity<Object> login(@Valid @RequestBody LoginReq body) {
        LoginOutcome outcome = auth.login(body);
        if (outcome instanceof LoginOutcome.SecondStepRequired second) {
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(second.challenge());
        }
        return ResponseEntity.ok(((LoginOutcome.SignedIn) outcome).response());
    }

    @PostMapping("/register/viewer")
    public ResponseEntity<AuthResponse> registerViewer(@Valid @RequestBody RegisterViewerReq body) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.registerViewer(body));
    }
}
