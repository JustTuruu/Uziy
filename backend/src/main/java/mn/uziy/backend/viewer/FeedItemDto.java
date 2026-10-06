package mn.uziy.backend.viewer;

import org.jspecify.annotations.Nullable;

public record FeedItemDto(
        long id,
        String title,
        String videoUrl,
        @Nullable String thumbnailUrl,
        int durationSeconds,
        boolean hasVideo,
        double rewardPerUser,
        String companyName) {
}
