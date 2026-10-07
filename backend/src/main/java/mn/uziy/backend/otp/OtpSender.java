package mn.uziy.backend.otp;

/**
 * Pattern: Strategy — how a one-time code reaches the person (SMS today's
 * logging stand-in, a real gateway or e-mail tomorrow). A new channel is a new
 * {@code @Component}; nothing else changes.
 */
public interface OtpSender {

    /** Delivers {@code code} to {@code phoneNumber}; throws when it could not be sent. */
    void send(String phoneNumber, String code, OtpPurpose purpose);
}
