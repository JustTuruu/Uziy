package mn.uziy.backend.notification;

/** Use case: a viewer's device announces (or withdraws) its push token. */
public interface DeviceRegistrationService {

    /** Upsert by token; a token already held by another user moves to this one. */
    void register(long userId, String token, DevicePlatform platform);

    /** Removes the caller's own token (e.g. on logout); unknown tokens are ignored. */
    void unregister(long userId, String token);
}
