package mn.uziy.backend.common;

/** The thing asked for does not exist → 404. */
public final class NotFoundException extends DomainException {
    public NotFoundException(String message) {
        super(message);
    }
}
