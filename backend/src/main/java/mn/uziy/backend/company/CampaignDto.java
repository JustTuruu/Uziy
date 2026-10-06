package mn.uziy.backend.company;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.TargetGender;
import org.jspecify.annotations.Nullable;

/**
 * @param totalBudget       amount charged (= payable P), whole ₮
 * @param costPerView       C — what one viewer costs the company (reward + platform commission)
 * @param rewardPerUser     R — what one viewer receives
 * @param targetViewers     N — viewers the budget buys
 * @param commissionPercent commission snapshot at creation; null for legacy (pre-V5) campaigns
 */
public record CampaignDto(
        long id,
        String title,
        String videoUrl,
        int durationSeconds,
        boolean hasVideo,
        TargetGender targetGender,
        int minAge,
        int maxAge,
        String targetCity,
        double totalBudget,
        double remainingBudget,
        double costPerView,
        double rewardPerUser,
        CampaignStatus status,
        OffsetDateTime createdAt,
        @Nullable Integer targetViewers,
        @Nullable Integer commissionPercent,
        @Nullable OffsetDateTime paidAt) {

    public static CampaignDto of(CampaignEntity c) {
        return new CampaignDto(
                c.getId(), c.getTitle(), c.getVideoUrl(),
                c.getDurationSeconds(),
                c.hasVideo(),
                c.getTargetGender(),
                c.getMinAge(), c.getMaxAge(), c.getTargetCity(),
                c.getTotalBudget(), c.getRemainingBudget(),
                c.getCostPerView(), c.getRewardPerUser(),
                c.getStatus(), c.getCreatedAt(),
                c.getTargetViewers(),
                c.getCommissionPercent(),
                c.getPaidAt());
    }
}
