package mn.uziy.backend.guest;

import java.util.List;
import mn.uziy.backend.viewer.FeedItemDto;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Unauthenticated HTTP adapter (see SecurityConfig: {@code /public/**} is open). */
@RestController
@RequestMapping("/public")
public class GuestController {

    private final GuestFeedService guestFeed;

    public GuestController(GuestFeedService guestFeed) {
        this.guestFeed = guestFeed;
    }

    @GetMapping("/feed")
    public List<FeedItemDto> feed() {
        return guestFeed.sampleFeed();
    }
}
