package mn.uziy.backend.phoneverify;

import java.util.UUID;
import mn.uziy.backend.common.Messages;

/** What the app needs to prove a phone before registering: open a check, then poll it. */
public interface PhoneVerificationService {

    String PHONE_TAKEN = Messages.PHONE_TAKEN;
    String NOT_FOUND = "Баталгаажуулалт олдсонгүй";
    String START_FAILED = "Баталгаажуулалт эхлүүлж чадсангүй. Дахин оролдоно уу";

    /**
     * Opens a check for a phone that has no account yet; any earlier check of that phone stops mattering.
     *
     * @throws mn.uziy.backend.common.ConflictException when the phone is already registered
     * @throws mn.uziy.backend.common.TooManyRequestsException within the cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    PhoneVerificationStartedRes start(String phoneNumber);

    /**
     * The check's current state, asking the provider while it is still pending.
     *
     * @throws mn.uziy.backend.common.NotFoundException for an unknown id
     */
    PhoneVerificationStateRes check(UUID verificationId);
}
