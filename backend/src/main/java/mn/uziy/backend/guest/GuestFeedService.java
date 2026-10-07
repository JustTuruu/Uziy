package mn.uziy.backend.guest;

import java.util.List;
import mn.uziy.backend.viewer.FeedItemDto;

/** What a not-signed-in visitor of the app may see: a few sample campaign cards, never the video itself. */
public interface GuestFeedService {

    /** How many sample cards a guest gets. */
    int SAMPLE_SIZE = 5;

    /** Newest campaigns that can still pay out, untargeted, with {@code videoUrl} blanked. */
    List<FeedItemDto> sampleFeed();
}
