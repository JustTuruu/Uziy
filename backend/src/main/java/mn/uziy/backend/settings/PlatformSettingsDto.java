package mn.uziy.backend.settings;

import java.time.OffsetDateTime;

public record PlatformSettingsDto(
        int commissionPercent,
        int minRewardPerViewer,
        OffsetDateTime updatedAt) {
}
