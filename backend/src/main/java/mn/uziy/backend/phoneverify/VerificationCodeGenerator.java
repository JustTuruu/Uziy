package mn.uziy.backend.otp;

import java.security.SecureRandom;
import org.springframework.stereotype.Component;

/** Draws uniformly random zero-padded numeric codes from a cryptographic source. */
@Component
public class OtpCodeGenerator {

    public static final int LENGTH = 6;
    private static final int BOUND = 1_000_000;

    private final SecureRandom random = new SecureRandom();

    public String next() {
        return String.format("%0" + LENGTH + "d", random.nextInt(BOUND));
    }
}
