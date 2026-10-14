package mn.uziy.backend.privacy;

import java.time.OffsetDateTime;
import java.util.Optional;
import org.jspecify.annotations.Nullable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Pattern: Repository — the consent columns of a viewer's row. */
@Repository
public class StatisticsConsentRepository {

    /** What is stored: null status = never asked. */
    public record Stored(@Nullable String status, @Nullable OffsetDateTime decidedAt, @Nullable String version) {
    }

    private final JdbcTemplate jdbc;

    public StatisticsConsentRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<Stored> findForViewer(long viewerId) {
        return jdbc.query("""
                SELECT stats_consent, stats_consent_at, stats_consent_version FROM users
                WHERE id = ? AND role = 'VIEWER'""",
                (rs, row) -> new Stored(rs.getString(1), rs.getObject(2, OffsetDateTime.class), rs.getString(3)),
                viewerId).stream().findFirst();
    }

    public void save(long viewerId, StatisticsConsentStatus status, OffsetDateTime at, String version) {
        jdbc.update("""
                UPDATE users SET stats_consent = ?, stats_consent_at = ?, stats_consent_version = ?
                WHERE id = ? AND role = 'VIEWER'""", status.name(), at, version, viewerId);
    }
}
