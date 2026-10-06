package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/**
 * Single-row config table. Enforced via a CHECK constraint that {@code id = 1}
 * (see V4__survey_only_campaigns.sql). Always load with {@code findById(1)}
 * (see {@link PlatformSettings#current}).
 *
 * <p>Since V5 it holds the commission model used by
 * {@code mn.uziy.backend.pricing.CampaignPricing} for BOTH video and survey-only
 * campaigns: the platform keeps {@code commissionPercent} of every viewer's cost,
 * and a viewer's reward may never drop below {@code minRewardPerViewer}.
 */
@Entity
@Table(name = "platform_settings")
public class PlatformSettingsEntity {

    @Id
    private int id = 1;

    /** Platform cut, whole percent, 1..90 (DB CHECK). */
    @Column(name = "commission_percent", nullable = false)
    private int commissionPercent = 30;

    /** Floor for a single viewer's reward, whole ₮, >= 1 (DB CHECK). */
    @Column(name = "min_reward_per_viewer", nullable = false)
    private int minRewardPerViewer = 100;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Column(name = "updated_by")
    private Long updatedBy;

    public PlatformSettingsEntity() {
    }

    public int getId() { return id; }
    public void setId(int id) { this.id = id; }

    public int getCommissionPercent() { return commissionPercent; }
    public void setCommissionPercent(int commissionPercent) { this.commissionPercent = commissionPercent; }

    public int getMinRewardPerViewer() { return minRewardPerViewer; }
    public void setMinRewardPerViewer(int minRewardPerViewer) { this.minRewardPerViewer = minRewardPerViewer; }

    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }

    public @Nullable Long getUpdatedBy() { return updatedBy; }
    public void setUpdatedBy(@Nullable Long updatedBy) { this.updatedBy = updatedBy; }
}
