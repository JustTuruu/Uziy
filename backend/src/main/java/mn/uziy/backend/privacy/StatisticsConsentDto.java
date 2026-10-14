package mn.uziy.backend.privacy;

import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/** The viewer's current choice and when it was made; {@code version} is the consent wording it applies to. */
public record StatisticsConsentDto(StatisticsConsentStatus status, @Nullable OffsetDateTime decidedAt, String version) {
}
