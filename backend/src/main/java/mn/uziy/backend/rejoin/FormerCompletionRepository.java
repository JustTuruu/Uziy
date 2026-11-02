package mn.uziy.backend.rejoin;

import java.util.HashSet;
import java.util.Set;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * Pattern: Repository — the campaigns a phone number already earned under accounts that were deleted. Each write is
 * one INSERT … SELECT, so nothing is read into memory and written back.
 */
@Repository
public class FormerCompletionRepository {

    private final JdbcTemplate jdbc;

    public FormerCompletionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Files every campaign the account completed — and every one it had itself inherited, so deleting a second time
     * keeps the first account's campaigns too — under {@code phoneHash}. Returns the number of new rows.
     */
    public int rememberCompletionsOf(long userId, String phoneHash) {
        return jdbc.update("""
                INSERT INTO former_completions (phone_hash, campaign_id)
                SELECT ?, campaign_id FROM view_history WHERE user_id = ?
                UNION
                SELECT ?, campaign_id FROM inherited_completions WHERE user_id = ?
                ON CONFLICT DO NOTHING""", phoneHash, userId, phoneHash, userId);
    }

    /** Gives the account every campaign filed under {@code phoneHash}. Returns the number of new rows. */
    public int inheritInto(long userId, String phoneHash) {
        return jdbc.update("""
                INSERT INTO inherited_completions (user_id, campaign_id)
                SELECT ?, campaign_id FROM former_completions WHERE phone_hash = ?
                ON CONFLICT DO NOTHING""", userId, phoneHash);
    }

    public Set<Long> inheritedCampaignIds(long userId) {
        return new HashSet<>(jdbc.queryForList(
                "SELECT campaign_id FROM inherited_completions WHERE user_id = ?", Long.class, userId));
    }

    public boolean isInherited(long userId, long campaignId) {
        Boolean found = jdbc.queryForObject(
                "SELECT EXISTS (SELECT 1 FROM inherited_completions WHERE user_id = ? AND campaign_id = ?)",
                Boolean.class, userId, campaignId);
        return Boolean.TRUE.equals(found);
    }
}
