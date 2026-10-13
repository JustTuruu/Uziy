package mn.uziy.backend.phoneverify;

/**
 * Pattern: Strategy — who confirms that a person holds a phone number (verify.mn in production, a simulated
 * stand-in for development). A new provider is a new {@code @Component}; nothing else changes.
 */
public interface PhoneVerificationGateway {

    /**
     * Opens a check in which the user texts {@code text} from {@code phoneNumber}.
     *
     * @throws PhoneVerificationGatewayException when the provider could not be reached or refused the call
     */
    PhoneVerificationSession start(String phoneNumber, String text);

    /**
     * The provider's current answer for {@code sessionId}; a session it no longer knows is {@code EXPIRED}.
     *
     * @throws PhoneVerificationGatewayException when the provider could not be reached
     */
    PhoneVerificationStatus status(String sessionId);
}
