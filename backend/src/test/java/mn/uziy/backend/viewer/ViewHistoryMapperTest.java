package mn.uziy.backend.viewer;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.ViewHistoryEntity;
import org.junit.jupiter.api.Test;

class ViewHistoryMapperTest {

    @Test
    void mapsTheViewTheCampaignTitleAndTheCompanyName() {
        ViewHistoryEntity view = new ViewHistoryEntity();
        view.setCampaignId(1L);
        view.setRewardPaid(700.0);
        OffsetDateTime at = OffsetDateTime.parse("2026-10-06T10:00:00+08:00");
        view.setWatchedAt(at);

        ViewHistoryItemDto dto = new ViewHistoryMapper().toDto(view, sampleCampaign(1), "MobiCom");

        assertThat(dto).isEqualTo(new ViewHistoryItemDto(1L, "Test", "MobiCom", 700.0, at));
    }
}
