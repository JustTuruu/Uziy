package mn.uziy.backend.media;

import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Pattern: Repository — stores one durable cover per campaign alongside its database backup. */
@Repository
public class CampaignImageRepository {
    private final JdbcTemplate jdbc;
    public CampaignImageRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    public record Image(byte[] content, String contentType) {}
    public void save(long id, Image image) {
        jdbc.update("""
                INSERT INTO campaign_images(campaign_id, content, content_type) VALUES (?, ?, ?)
                ON CONFLICT (campaign_id) DO UPDATE SET content = EXCLUDED.content, content_type = EXCLUDED.content_type
                """, id, image.content(), image.contentType());
    }
    public Optional<Image> find(long id) {
        return jdbc.query("SELECT content, content_type FROM campaign_images WHERE campaign_id = ?",
                (rs, row) -> new Image(rs.getBytes(1), rs.getString(2)), id).stream().findFirst();
    }
    public void delete(long id) { jdbc.update("DELETE FROM campaign_images WHERE campaign_id = ?", id); }
}
