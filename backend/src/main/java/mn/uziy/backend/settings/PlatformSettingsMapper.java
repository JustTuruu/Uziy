package mn.uziy.backend.settings;

import mn.uziy.backend.domain.PlatformSettingsEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — turns the singleton settings row into its DTO. */
@Component
public class PlatformSettingsMapper {

    public PlatformSettingsDto toDto(PlatformSettingsEntity e) {
        return new PlatformSettingsDto(e.getCommissionPercent(), e.getMinRewardPerViewer(), e.getUpdatedAt());
    }
}
