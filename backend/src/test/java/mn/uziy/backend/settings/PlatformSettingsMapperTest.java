package mn.uziy.backend.settings;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.PlatformSettingsEntity;
import org.junit.jupiter.api.Test;

class PlatformSettingsMapperTest {

    @Test
    void mapsAllFields() {
        PlatformSettingsEntity e = new PlatformSettingsEntity();
        e.setCommissionPercent(33);
        e.setMinRewardPerViewer(150);
        OffsetDateTime at = OffsetDateTime.now();
        e.setUpdatedAt(at);

        PlatformSettingsDto dto = new PlatformSettingsMapper().toDto(e);

        assertThat(dto.commissionPercent()).isEqualTo(33);
        assertThat(dto.minRewardPerViewer()).isEqualTo(150);
        assertThat(dto.updatedAt()).isEqualTo(at);
    }
}
