package mn.uziy.backend.otp;

/** Issues and redeems one-time codes. Knows nothing about accounts. */
public interface OtpService {

    /** Message for a wrong, expired, used or exhausted code (kept identical so it leaks nothing). */
    String INVALID_CODE = "Код буруу эсвэл хугацаа дууссан байна";
    String TOO_SOON = "Түр хүлээгээд дахин оролдоно уу";
    String TOO_MANY = "Хэт олон код хүссэн байна. Дараа дахин оролдоно уу";
    String SEND_FAILED = "Код илгээж чадсангүй. Дахин оролдоно уу";

    /**
     * Sends a fresh code to {@code phoneNumber}; any earlier code stops working.
     *
     * @throws mn.uziy.backend.common.TooManyRequestsException when asked again within the
     *         cool-down or more than the hourly limit
     * @throws mn.uziy.backend.common.UnavailableException when the sender fails
     */
    void issue(String phoneNumber, OtpPurpose purpose);

    /**
     * Checks {@code code} against the newest code for this phone + purpose and, when it matches,
     * uses it up. Every wrong guess counts toward the attempt limit.
     *
     * @throws mn.uziy.backend.common.BadRequestException with {@link #INVALID_CODE}
     */
    void verifyAndConsume(String phoneNumber, OtpPurpose purpose, String code);
}
