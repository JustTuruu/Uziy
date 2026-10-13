package mn.uziy.backend.phoneverify;

/** The phone verification provider failed (network, bad API key, unexpected answer). Never a user error. */
public class PhoneVerificationGatewayException extends RuntimeException {

    public PhoneVerificationGatewayException(String message) {
        super(message);
    }

    public PhoneVerificationGatewayException(String message, Throwable cause) {
        super(message, cause);
    }
}
