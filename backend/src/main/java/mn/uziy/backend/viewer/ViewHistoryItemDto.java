package mn.uziy.backend.viewer;

import java.time.OffsetDateTime;

/** One row of the viewer's watch history: what was completed, for whom, when, and the reward paid. */
public record ViewHistoryItemDto(
        long campaignId,
        String title,
        String companyName,
        double rewardPaid,
        OffsetDateTime watchedAt) {
}
