package mn.uziy.backend.admin;

import java.time.OffsetDateTime;
import java.util.List;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Pattern: Repository — company accounts with their survey counts, in one query (no per-company lookups). */
@Repository
public class CompanyAccountRepository {

    private final JdbcTemplate jdbc;

    public CompanyAccountRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Every company account, newest first. */
    public List<CompanyListing> listWithCampaignCounts() {
        return jdbc.query("""
                SELECT u.id, u.company_name, u.phone_number, u.created_at, COUNT(c.id)
                FROM users u LEFT JOIN campaigns c ON c.company_id = u.id
                WHERE u.role = 'COMPANY'
                GROUP BY u.id
                ORDER BY u.created_at DESC, u.id DESC""",
                (rs, row) -> new CompanyListing(rs.getLong(1), rs.getString(2), rs.getString(3),
                        rs.getObject(4, OffsetDateTime.class), rs.getLong(5)));
    }
}
