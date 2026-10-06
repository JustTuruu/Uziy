package mn.uziy.backend.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.OffsetDateTime;
import org.jspecify.annotations.Nullable;

/**
 * A company's ad campaign.
 *
 * <p>Lifecycle (V5): created → AWAITING_PAYMENT → (company pays) → PENDING
 * (= paid, awaiting admin moderation) → ACTIVE | REJECTED. Afterwards the
 * company may toggle ACTIVE ⇄ PAUSED and end with COMPLETED.
 */
@Entity
@Table(name = "campaigns")
public class CampaignEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "company_id", nullable = false)
    private long companyId = 0;

    @Column(nullable = false, length = 200)
    private String title = "";

    @Column(name = "video_url", nullable = false, length = 500)
    private String videoUrl = "";

    @Column(name = "thumbnail_url", length = 500)
    private String thumbnailUrl;

    @Column(name = "duration_seconds", nullable = false)
    private int durationSeconds = 30;

    @Enumerated(EnumType.STRING)
    @Column(name = "target_gender", nullable = false, length = 10)
    private TargetGender targetGender = TargetGender.ALL;

    @Column(name = "min_age", nullable = false)
    private int minAge = 0;

    @Column(name = "max_age", nullable = false)
    private int maxAge = 100;

    @Column(name = "target_city", nullable = false, length = 50)
    private String targetCity = "ALL";

    @Column(name = "total_budget", nullable = false)
    private double totalBudget = 0.0;

    @Column(name = "remaining_budget", nullable = false)
    private double remainingBudget = 0.0;

    @Column(name = "cost_per_view", nullable = false)
    private double costPerView = 0.0;

    @Column(name = "reward_per_user", nullable = false)
    private double rewardPerUser = 0.0;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private CampaignStatus status = CampaignStatus.AWAITING_PAYMENT;

    /** N — how many viewers the paid budget buys. V5 backfilled pre-existing rows as floor(total / cost). */
    @Column(name = "target_viewers")
    private Integer targetViewers;

    /** Snapshot of platform_settings.commission_percent at creation. NULL for legacy (pre-V5) rows. */
    @Column(name = "commission_percent")
    private Integer commissionPercent;

    /** When the company paid (AWAITING_PAYMENT → PENDING). */
    @Column(name = "paid_at")
    private OffsetDateTime paidAt;

    /** false → survey-only campaign (viewer answers survey directly). */
    @Column(name = "has_video", nullable = false)
    private boolean hasVideo = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    public CampaignEntity() {
    }

    public @Nullable Long getId() { return id; }
    public void setId(@Nullable Long id) { this.id = id; }

    public long getCompanyId() { return companyId; }
    public void setCompanyId(long companyId) { this.companyId = companyId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getVideoUrl() { return videoUrl; }
    public void setVideoUrl(String videoUrl) { this.videoUrl = videoUrl; }

    public @Nullable String getThumbnailUrl() { return thumbnailUrl; }
    public void setThumbnailUrl(@Nullable String thumbnailUrl) { this.thumbnailUrl = thumbnailUrl; }

    public int getDurationSeconds() { return durationSeconds; }
    public void setDurationSeconds(int durationSeconds) { this.durationSeconds = durationSeconds; }

    public TargetGender getTargetGender() { return targetGender; }
    public void setTargetGender(TargetGender targetGender) { this.targetGender = targetGender; }

    public int getMinAge() { return minAge; }
    public void setMinAge(int minAge) { this.minAge = minAge; }

    public int getMaxAge() { return maxAge; }
    public void setMaxAge(int maxAge) { this.maxAge = maxAge; }

    public String getTargetCity() { return targetCity; }
    public void setTargetCity(String targetCity) { this.targetCity = targetCity; }

    public double getTotalBudget() { return totalBudget; }
    public void setTotalBudget(double totalBudget) { this.totalBudget = totalBudget; }

    public double getRemainingBudget() { return remainingBudget; }
    public void setRemainingBudget(double remainingBudget) { this.remainingBudget = remainingBudget; }

    public double getCostPerView() { return costPerView; }
    public void setCostPerView(double costPerView) { this.costPerView = costPerView; }

    public double getRewardPerUser() { return rewardPerUser; }
    public void setRewardPerUser(double rewardPerUser) { this.rewardPerUser = rewardPerUser; }

    public CampaignStatus getStatus() { return status; }
    public void setStatus(CampaignStatus status) { this.status = status; }

    public @Nullable Integer getTargetViewers() { return targetViewers; }
    public void setTargetViewers(@Nullable Integer targetViewers) { this.targetViewers = targetViewers; }

    public @Nullable Integer getCommissionPercent() { return commissionPercent; }
    public void setCommissionPercent(@Nullable Integer commissionPercent) { this.commissionPercent = commissionPercent; }

    public @Nullable OffsetDateTime getPaidAt() { return paidAt; }
    public void setPaidAt(@Nullable OffsetDateTime paidAt) { this.paidAt = paidAt; }

    public boolean hasVideo() { return hasVideo; }
    public void setHasVideo(boolean hasVideo) { this.hasVideo = hasVideo; }

    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }

    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
