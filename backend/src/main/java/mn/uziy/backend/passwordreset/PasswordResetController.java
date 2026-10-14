package mn.uziy.backend.passwordreset;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP adapter for a forgotten password (open: /auth/** needs no token). The phone is proved first through
 * {@code POST /auth/phone-verifications} with {@code purpose: PASSWORD_RESET}.
 */
@RestController
public class PasswordResetController {

    private final PasswordResetService passwordReset;

    public PasswordResetController(PasswordResetService passwordReset) {
        this.passwordReset = passwordReset;
    }

    @PostMapping("/auth/password/reset")
    public ResponseEntity<Void> reset(@Valid @RequestBody ResetPasswordReq body) {
        passwordReset.reset(body);
        return ResponseEntity.noContent().build();
    }
}
