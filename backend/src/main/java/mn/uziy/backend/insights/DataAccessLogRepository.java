package mn.uziy.backend.insights;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Pattern: Repository — the append-only record of who looked at which statistic. */
@Repository
public class DataAccessLogRepository {

    static final int DETAIL_MAX = 500;

    private final JdbcTemplate jdbc;

    public DataAccessLogRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public void record(long adminId, String action, String detail) {
        String shortDetail = detail.length() > DETAIL_MAX ? detail.substring(0, DETAIL_MAX) : detail;
        jdbc.update("INSERT INTO data_access_log (admin_id, action, detail) VALUES (?, ?, ?)",
                adminId, action, shortDetail);
    }

    public List<InsightsDtos.AccessLogEntry> recent(int limit) {
        return jdbc.query("""
                SELECT l.id, u.phone_number, l.action, l.detail, l.created_at
                FROM data_access_log l JOIN users u ON u.id = l.admin_id
                ORDER BY l.created_at DESC, l.id DESC LIMIT ?""",
                (rs, row) -> new InsightsDtos.AccessLogEntry(rs.getLong(1), rs.getString(2), rs.getString(3),
                        rs.getString(4), rs.getObject(5, OffsetDateTime.class)),
                limit);
    }
}
