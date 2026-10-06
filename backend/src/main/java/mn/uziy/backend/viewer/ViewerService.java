package mn.uziy.backend.viewer;

import java.util.List;
import mn.uziy.backend.auth.Me;

/** Read-side use cases of the viewer app: profile, home feed, survey questions. */
public interface ViewerService {
    Me me(long userId);

    /**
     * Home feed. Spec §4B — ACTIVE campaigns matching demographics that this
     * user hasn't watched, with enough budget for at least one more view.
     */
    List<FeedItemDto> feed(long userId);

    List<QuestionDto> questions(long campaignId);
}
