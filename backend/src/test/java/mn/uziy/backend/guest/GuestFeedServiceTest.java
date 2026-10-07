package mn.uziy.backend.guest;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.viewer.FeedItemDto;
import mn.uziy.backend.viewer.FeedItemMapper;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageRequest;

class GuestFeedServiceTest {

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final GuestFeedServiceImpl service = new GuestFeedServiceImpl(campaigns, users, new FeedItemMapper());

    private static UserEntity company(String name) {
        UserEntity company = new UserEntity();
        company.setId(500L);
        company.setCompanyName(name);
        return company;
    }

    @Test
    void returnsTheSampleWithCompanyNamesAndNoVideoUrl() {
        var campaign = sampleCampaign(1);
        campaign.setVideoUrl("https://cdn/secret.m3u8");
        when(campaigns.findPayableNewestFirst(PageRequest.ofSize(GuestFeedService.SAMPLE_SIZE)))
                .thenReturn(List.of(campaign));
        when(users.findAllById(List.of(500L))).thenReturn(List.of(company("MobiCom")));

        List<FeedItemDto> feed = service.sampleFeed();

        assertThat(feed).hasSize(1);
        assertThat(feed.get(0).companyName()).isEqualTo("MobiCom");
        assertThat(feed.get(0).videoUrl()).isEmpty();
        assertThat(feed.get(0).rewardPerUser()).isEqualTo(700.0);
    }

    @Test
    void isEmptyWhenNoCampaignCanPayOut() {
        when(campaigns.findPayableNewestFirst(PageRequest.ofSize(GuestFeedService.SAMPLE_SIZE)))
                .thenReturn(List.of());

        assertThat(service.sampleFeed()).isEmpty();
    }

    @Test
    void usesAnEmptyCompanyNameWhenTheCompanyHasNone() {
        when(campaigns.findPayableNewestFirst(PageRequest.ofSize(GuestFeedService.SAMPLE_SIZE)))
                .thenReturn(List.of(sampleCampaign(1)));
        when(users.findAllById(List.of(500L))).thenReturn(List.of(company(null)));

        assertThat(service.sampleFeed().get(0).companyName()).isEmpty();
    }
}
