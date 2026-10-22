package mn.uziy.backend.adminlogin;

import jakarta.validation.Valid;
import mn.uziy.backend.auth.AuthResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP adapter for the admin login's second step (open: /auth/** needs no token).
 *
 * <p>Flow: {@code POST /auth/login} with an admin's correct password answers <b>202 Accepted</b> with
 * {@link AdminLoginChallenge} ({@code {"twoStep": {...}}}, no token). The admin texts {@code smsText} from the
 * account's phone to {@code shortcode}; the panel polls {@code GET /auth/phone-verifications/{verificationId}} every
 * few seconds and, once it says {@code VERIFIED}, calls {@code POST /auth/admin/login/verify} here, which answers
 * 200 with the usual {@link AuthResponse}. A check that is not confirmed, already used, too old, or opened for
 * another phone or purpose answers 400.
 */
@RestController
@RequestMapping("/auth/admin/login")
public class AdminLoginController {

    private final AdminLoginService adminLogin;

    public AdminLoginController(AdminLoginService adminLogin) {
        this.adminLogin = adminLogin;
    }

    @PostMapping("/verify")
    public AuthResponse verify(@Valid @RequestBody AdminLoginVerifyReq body) {
        return adminLogin.verify(body);
    }
}
