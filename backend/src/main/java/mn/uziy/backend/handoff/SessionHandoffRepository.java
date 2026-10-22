package mn.uziy.backend.handoff;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Pattern: Repository — handoff codes; spending one is a single conditional UPDATE, so it works only once. */
@Repository
public class SessionHandoffRepository {

    private final JdbcTemplate jdbc;

    public SessionHandoffRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void insert(long userId, String codeHash, OffsetDateTime createdAt, OffsetDateTime expiresAt) {
        jdbc.update("INSERT INTO session_handoffs (user_id, code_hash, created_at, expires_at) VALUES (?, ?, ?, ?)",
                userId, codeHash, createdAt, expiresAt);
    }

    /** Marks the code used if it is unused and not expired at {@code now}; the owner's id, or empty. */
    public Optional<Long> trySpend(String codeHash, OffsetDateTime now) {
        List<Long> ids = jdbc.queryForList("""
                UPDATE session_handoffs SET used_at = ?
                WHERE code_hash = ? AND used_at IS NULL AND expires_at > ?
                RETURNING user_id""", Long.class, now, codeHash, now);
        return ids.stream().findFirst();
    }

    /** Old rows are useless; keeps the table tiny. */
    public void deleteExpiredBefore(OffsetDateTime cutoff) {
        jdbc.update("DELETE FROM session_handoffs WHERE expires_at < ?", cutoff);
    }
}
