package mn.uziy.backend.guest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.viewer.FeedItemDto;
import org.junit.jupiter.api.Test;

class GuestControllerTest {

    @Test
    void feedDelegatesToTheGuestFeedService() {
        GuestFeedService service = mock(GuestFeedService.class);
        List<FeedItemDto> sample = List.of(new FeedItemDto(1L, "t", "", null, 30, true, 700.0, "c"));
        when(service.sampleFeed()).thenReturn(sample);

        assertThat(new GuestController(service).feed()).isSameAs(sample);
    }
}
