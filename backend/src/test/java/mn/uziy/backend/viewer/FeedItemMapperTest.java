package mn.uziy.backend.viewer;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class FeedItemMapperTest {

    @Test
    void mapsCampaignAndCompanyName() {
        FeedItemDto dto = new FeedItemMapper().toDto(sampleCampaign(3), "MobiCom");
        assertThat(dto.id()).isEqualTo(3L);
        assertThat(dto.title()).isEqualTo("Test");
        assertThat(dto.durationSeconds()).isEqualTo(30);
        assertThat(dto.rewardPerUser()).isEqualTo(700.0);
        assertThat(dto.companyName()).isEqualTo("MobiCom");
    }

    @Test
    void guestCardKeepsTheTeaserButDropsTheVideoUrl() {
        var campaign = sampleCampaign(3);
        campaign.setVideoUrl("https://cdn/x.m3u8");

        FeedItemDto dto = new FeedItemMapper().toGuestDto(campaign, "MobiCom");

        assertThat(dto.videoUrl()).isEmpty();
        assertThat(dto.title()).isEqualTo("Test");
        assertThat(dto.rewardPerUser()).isEqualTo(700.0);
        assertThat(dto.companyName()).isEqualTo("MobiCom");
    }
}
