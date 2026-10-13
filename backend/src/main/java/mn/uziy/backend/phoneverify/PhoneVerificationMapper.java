package mn.uziy.backend.phoneverify;

import org.springframework.stereotype.Component;

/** Pattern: Mapper — phone-check rows (plus the provider's instructions) to API responses. */
@Component
public class PhoneVerificationMapper {

    public PhoneVerificationStartedRes toStarted(PhoneVerificationEntity row, PhoneVerificationSession session) {
        return new PhoneVerificationStartedRes(row.getId(), row.getPhoneNumber(), session.shortcode(),
                session.text(), session.smsUri(), session.displayInstruction(), row.getStatus(), row.getExpiresAt());
    }

    public PhoneVerificationStateRes toState(PhoneVerificationEntity row) {
        return new PhoneVerificationStateRes(row.getId(), row.getStatus(), row.getExpiresAt());
    }
}
