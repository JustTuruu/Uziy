package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/** A viewer's completed view of a campaign (one row per user+campaign); records the reward paid. */
@Entity
@Table(name = "view_history")
public class ViewHistoryEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private long userId = 0;

    @Column(name = "campaign_id", nullable = false)
    private long campaignId = 0;

    @Column(name = "reward_paid", nullable = false)
    private double rewardPaid = 0.0;

    @Column(name = "watched_at", nullable = false, updatable = false)
    private OffsetDateTime watchedAt = OffsetDateTime.now();

    public ViewHistoryEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getUserId() { return userId; }
    public void setUserId(long userId) { this.userId = userId; }

    public long getCampaignId() { return campaignId; }
    public void setCampaignId(long campaignId) { this.campaignId = campaignId; }

    public double getRewardPaid() { return rewardPaid; }
    public void setRewardPaid(double rewardPaid) { this.rewardPaid = rewardPaid; }

    public OffsetDateTime getWatchedAt() { return watchedAt; }
    public void setWatchedAt(OffsetDateTime watchedAt) { this.watchedAt = watchedAt; }
}
