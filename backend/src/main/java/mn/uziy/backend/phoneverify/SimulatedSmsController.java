package mn.uziy.backend.phoneverify;

import mn.uziy.backend.common.NotFoundException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Development only — exists only with the simulated provider (which production refuses): stands in for the
 * user's SMS reaching verify.mn, so a check can be completed on a laptop or an emulator.
 */
@RestController
@ConditionalOnProperty(prefix = "uziy.phone-verification", name = "provider", havingValue = "simulated",
        matchIfMissing = true)
public class SimulatedSmsController {

    static final String PATH = "/auth/phone-verifications/simulated-sms/{sessionId}";
    static final String UNKNOWN_SESSION = "Туршилтын session олдсонгүй";

    private final SimulatedPhoneVerificationGateway gateway;

    public SimulatedSmsController(SimulatedPhoneVerificationGateway gateway) {
        this.gateway = gateway;
    }

    @PostMapping(PATH)
    public ResponseEntity<Void> receive(@PathVariable("sessionId") String sessionId) {
        if (!gateway.receiveSms(sessionId)) {
            throw new NotFoundException(UNKNOWN_SESSION);
        }
        return ResponseEntity.noContent().build();
    }
}
