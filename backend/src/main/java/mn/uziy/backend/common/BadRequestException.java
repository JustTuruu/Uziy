package mn.uziy.backend.common;

/** The request itself is invalid → 400. */
public final class BadRequestException extends DomainException {
    public BadRequestException(String message) {
        super(message);
    }
}
