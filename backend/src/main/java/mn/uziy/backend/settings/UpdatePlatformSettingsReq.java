package mn.uziy.backend.settings;

import org.jspecify.annotations.Nullable;

/**
 * Every field required — {@code commissionPercent} is the default for video campaigns, {@code surveyCommissionPercent}
 * for survey-only ones; nullable only so a missing field gets our Mongolian 400.
 */
public record UpdatePlatformSettingsReq(
        @Nullable Integer commissionPercent,
        @Nullable Integer surveyCommissionPercent,
        @Nullable Integer minRewardPerViewer) {
}
