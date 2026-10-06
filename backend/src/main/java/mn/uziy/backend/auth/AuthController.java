package mn.uziy.backend.auth;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter only — credential checking and account creation live in {@link AuthService}. */
@RestController
@RequestMapping("/auth")
public class AuthController {

    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginReq body) {
        return auth.login(body);
    }

    @PostMapping("/register/viewer")
    public ResponseEntity<AuthResponse> registerViewer(@Valid @RequestBody RegisterViewerReq body) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.registerViewer(body));
    }

    @PostMapping("/register/company")
    public ResponseEntity<AuthResponse> registerCompany(@Valid @RequestBody RegisterCompanyReq body) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.registerCompany(body));
    }
}
