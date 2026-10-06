package mn.uziy.backend.domain;

/**
 * Loads the singleton config row. Kept as a static helper (not a default method on the
 * repository) so it can be mocked: default methods on JPA interfaces are intercepted by
 * Spring's proxy before the default body ever runs.
 */
public final class PlatformSettings {

    private static final int SINGLETON_ID = 1;

    private PlatformSettings() {
    }

    public static PlatformSettingsEntity current(PlatformSettingsRepository repository) {
        return repository.findById(SINGLETON_ID)
                .orElseThrow(() -> new IllegalStateException("platform_settings row missing"));
    }
}
