package mn.uziy.backend.viewer;

import jakarta.validation.Valid;
import java.util.List;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for the viewer app — all behaviour lives in the services. */
@RestController
@RequestMapping("/viewer")
@PreAuthorize("hasRole('VIEWER')")
public class ViewerController {

    private final ViewerService profile;
    private final RewardService rewards;

    public ViewerController(ViewerService profile, RewardService rewards) {
        this.profile = profile;
        this.rewards = rewards;
    }

    @GetMapping("/me")
    public Me me(@Auth JwtPrincipal principal) {
        return profile.me(principal.userId());
    }

    @GetMapping("/feed")
    public List<FeedItemDto> feed(@Auth JwtPrincipal principal) {
        return profile.feed(principal.userId());
    }

    @GetMapping("/history")
    public List<ViewHistoryItemDto> history(@Auth JwtPrincipal principal) {
        return profile.history(principal.userId());
    }

    @GetMapping("/campaigns/{id}/questions")
    public List<QuestionDto> questions(@PathVariable("id") long id) {
        return profile.questions(id);
    }

    @PostMapping("/campaigns/{id}/submit")
    public RewardResult submit(
            @PathVariable("id") long id,
            @Valid @RequestBody SubmitSurveyReq body,
            @Auth JwtPrincipal principal) {
        return rewards.submitSurvey(principal.userId(), id, body.answers());
    }
}
