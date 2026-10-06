package mn.uziy.backend.common;

/** The request is valid but clashes with current state → 409. */
public final class ConflictException extends DomainException {
    public ConflictException(String message) {
        super(message);
    }
}
