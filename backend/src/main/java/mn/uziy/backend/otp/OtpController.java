package mn.uziy.backend.otp;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for one-time codes and password reset (open: /auth/** needs no token). */
@RestController
@RequestMapping("/auth")
public class OtpController {

    private final OtpRequestService requests;
    private final PasswordResetService passwordReset;

    public OtpController(OtpRequestService requests, PasswordResetService passwordReset) {
        this.requests = requests;
        this.passwordReset = passwordReset;
    }

    @PostMapping("/otp/request")
    public ResponseEntity<Void> request(@Valid @RequestBody OtpRequestReq body) {
        requests.requestCode(body.phoneNumber(), body.purpose());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/password/reset")
    public ResponseEntity<Void> reset(@Valid @RequestBody ResetPasswordReq body) {
        passwordReset.reset(body);
        return ResponseEntity.noContent().build();
    }
}
