package mn.uziy.backend.domain;

import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/**
 * What every authenticated request checks about its account: the role it has now, and when its password last
 * changed (tokens issued before that are no longer accepted).
 */
public record AccountState(Role role, @Nullable OffsetDateTime credentialsChangedAt) {
}
