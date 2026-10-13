package mn.uziy.backend.phoneverify;

import jakarta.validation.constraints.Pattern;

public record StartPhoneVerificationReq(@Pattern(regexp = "\\d{8}") String phoneNumber) {
}
