package mn.uziy.backend.viewer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;

/** The controller is an adapter: it passes the caller's id to the services and nothing more. */
class ViewerControllerTest {

    private final ViewerService profile = mock(ViewerService.class);
    private final RewardService rewards = mock(RewardService.class);
    private final ViewerController controller = new ViewerController(profile, rewards);
    private final JwtPrincipal principal = new JwtPrincipal(42L, Role.VIEWER);

    @Test
    void meAndFeedUseTheCallersId() {
        Me me = new Me(42L, "77000001", Role.VIEWER, null, null, null, 0.0, false, null);
        when(profile.me(42L)).thenReturn(me);
        when(profile.feed(42L)).thenReturn(List.of());

        assertThat(controller.me(principal)).isSameAs(me);
        assertThat(controller.feed(principal)).isEmpty();
    }

    @Test
    void historyUsesTheCallersId() {
        when(profile.history(42L)).thenReturn(List.of());

        assertThat(controller.history(principal)).isEmpty();
    }

    @Test
    void questionsDelegatesByCampaignId() {
        when(profile.questions(7L)).thenReturn(List.of());
        assertThat(controller.questions(7L)).isEmpty();
    }

    @Test
    void submitHandsTheCallersIdCampaignAndAnswersToTheRewardService() {
        List<SubmitSurveyReq.Answer> answers = List.of(new SubmitSurveyReq.Answer(10L, "\"Тийм\""));
        RewardResult result = new RewardResult(700.0, 700.0);
        when(rewards.submitSurvey(42L, 1L, answers)).thenReturn(result);

        assertThat(controller.submit(1L, new SubmitSurveyReq(answers), principal)).isSameAs(result);
    }
}
