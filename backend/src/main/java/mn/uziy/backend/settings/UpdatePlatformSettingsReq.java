package mn.uziy.backend.settings;

import org.jspecify.annotations.Nullable;

/** Both fields required — nullable only so a missing field gets our Mongolian 400. */
public record UpdatePlatformSettingsReq(
        @Nullable Integer commissionPercent,
        @Nullable Integer minRewardPerViewer) {
}
