package mn.uziy.backend.common;

/** The thing exists but belongs to someone else → 403. */
public final class ForbiddenException extends DomainException {
    public ForbiddenException(String message) {
        super(message);
    }
}
