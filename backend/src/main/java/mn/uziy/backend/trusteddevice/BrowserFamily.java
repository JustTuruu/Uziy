package mn.uziy.backend.trusteddevice;

import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * A remembered browser's label: only its family ("Chrome", "Safari", …), read from the User-Agent. The full
 * User-Agent is never stored — with the version and OS it narrows down a person; the family alone does not.
 */
public final class BrowserFamily {

    private record Marker(String token, String family) {
    }

    /** Checked in order: Edge and Opera also say "Chrome", Chrome also says "Safari". */
    private static final List<Marker> MARKERS = List.of(
            new Marker("Edg", "Edge"),
            new Marker("OPR/", "Opera"),
            new Marker("SamsungBrowser/", "Samsung Internet"),
            new Marker("Firefox/", "Firefox"),
            new Marker("FxiOS/", "Firefox"),
            new Marker("CriOS/", "Chrome"),
            new Marker("Chrome/", "Chrome"),
            new Marker("Safari/", "Safari"));

    private BrowserFamily() {
    }

    public static Optional<String> of(@Nullable String userAgent) {
        if (userAgent == null || userAgent.isBlank()) {
            return Optional.empty();
        }
        return MARKERS.stream()
                .filter(m -> userAgent.contains(m.token()))
                .map(Marker::family)
                .findFirst();
    }
}
