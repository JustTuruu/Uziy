package mn.uziy.backend.common;

/** A required collaborator (e.g. a payment gateway) is not available → 503. */
public final class UnavailableException extends DomainException {
    public UnavailableException(String message) {
        super(message);
    }
}
