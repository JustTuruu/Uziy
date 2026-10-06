package mn.uziy.backend.common;

/** Credentials were not accepted → 401. */
public final class UnauthorizedException extends DomainException {
    public UnauthorizedException(String message) {
        super(message);
    }
}
