package mn.uziy.backend.phoneverify;

import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for proving a phone before registration or a password reset (open: /auth/** needs no token). */
@RestController
@RequestMapping("/auth/phone-verifications")
public class PhoneVerificationController {

    private final PhoneVerificationService verifications;

    public PhoneVerificationController(PhoneVerificationService verifications) {
        this.verifications = verifications;
    }

    @PostMapping
    public ResponseEntity<PhoneVerificationStartedRes> start(@Valid @RequestBody StartPhoneVerificationReq body) {
        return ResponseEntity.status(HttpStatus.CREATED).body(verifications.start(body.phoneNumber(), body.purposeOrDefault()));
    }

    @GetMapping("/{verificationId}")
    public PhoneVerificationStateRes check(@PathVariable("verificationId") UUID verificationId) {
        return verifications.check(verificationId);
    }
}
