package mn.uziy.backend.common;

/** The caller is asking too often (e.g. a new one-time code) → 429. */
public final class TooManyRequestsException extends DomainException {
    public TooManyRequestsException(String message) {
        super(message);
    }
}
