package mn.uziy.backend.phoneverify;

import java.util.UUID;
import mn.uziy.backend.common.Messages;

/** What the app needs to prove a phone before registering or resetting a password: open a check, then poll it. */
public interface PhoneVerificationService {

    String PHONE_TAKEN = Messages.PHONE_TAKEN;
    String NOT_FOUND = "Баталгаажуулалт олдсонгүй";
    String START_FAILED = "Баталгаажуулалт эхлүүлж чадсангүй. Дахин оролдоно уу";
    String ACCOUNT_NOT_FOUND = "Энэ дугаараар бүртгэл олдсонгүй. Дугаараа шалгах эсвэл бүртгүүлнэ үү";
    String TOO_SOON = "Түр хүлээгээд дахин оролдоно уу";
    String TOO_MANY = "Хэт олон удаа оролдлоо. Дараа дахин оролдоно уу";
    /** A console-login check is opened only by the login itself, never through the public endpoint. */
    String PURPOSE_NOT_OFFERED = "Энэ баталгаажуулалтыг эндээс эхлүүлэх боломжгүй";

    /**
     * Opens a check of {@code phoneNumber} for {@code purpose}; any earlier check of that phone stops mattering.
     *
     * @throws mn.uziy.backend.common.ConflictException registering a phone that already has an account
     * @throws mn.uziy.backend.common.NotFoundException resetting a password for a phone with no viewer account
     * @throws mn.uziy.backend.common.TooManyRequestsException within the cool-down or past the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the provider fails
     */
    PhoneVerificationStartedRes start(String phoneNumber, PhoneVerificationPurpose purpose);

    /**
     * The check's current state, asking the provider while it is still pending.
     *
     * @throws mn.uziy.backend.common.NotFoundException for an unknown id
     */
    PhoneVerificationStateRes check(UUID verificationId);
}
