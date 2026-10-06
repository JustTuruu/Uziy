package mn.uziy.backend.settings;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.PlatformSettingsEntity;

public record PlatformSettingsDto(
        int commissionPercent,
        int minRewardPerViewer,
        OffsetDateTime updatedAt) {

    public static PlatformSettingsDto of(PlatformSettingsEntity e) {
        return new PlatformSettingsDto(e.getCommissionPercent(), e.getMinRewardPerViewer(), e.getUpdatedAt());
    }
}
