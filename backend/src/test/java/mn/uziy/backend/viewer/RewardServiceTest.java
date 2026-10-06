package mn.uziy.backend.viewer;

import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static mn.uziy.backend.viewer.ViewerTestData.viewer;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.SurveyResponseRepository;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryEntity;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class RewardServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);
    private final ViewHistoryRepository history = mock(ViewHistoryRepository.class);
    private final SurveyResponseRepository responses = mock(SurveyResponseRepository.class);

    private final RewardServiceImpl service =
            new RewardServiceImpl(users, campaigns, questions, history, responses);

    private final UserEntity viewer = viewer();

    @Test
    void submitCreditsRewardMarksViewAndReturnsNewBalance() {
        when(history.existsByUserIdAndCampaignId(42L, 1L)).thenReturn(false);
        when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1)));
        when(campaigns.tryDecrementBudget(1L)).thenReturn(1);

        ViewHistoryEntity savedView = new ViewHistoryEntity();
        savedView.setId(999L);
        savedView.setUserId(42L);
        savedView.setCampaignId(1L);
        savedView.setRewardPaid(700.0);
        when(history.save(any())).thenReturn(savedView);

        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(10L);
        q.setCampaignId(1L);
        q.setPosition(1);
        q.setPrompt("P");
        q.setQType("SINGLE_CHOICE");
        q.setOptionsJson("[]");
        q.setRequired(true);
        when(questions.findAllByCampaignIdOrderByPosition(1L)).thenReturn(List.of(q));
        when(responses.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        when(users.save(saved.capture())).thenAnswer(inv -> inv.getArgument(0));

        RewardResult result = service.submitSurvey(42L, 1L, List.of(
                new SubmitSurveyReq.Answer(10L, "\"Тийм\""),
                new SubmitSurveyReq.Answer(999L, "\"ignored — not a real question\"")));

        assertThat(result.rewardPaid()).isEqualTo(700.0);
        assertThat(result.newBalance()).isEqualTo(700.0);
        assertThat(saved.getValue().getBalance()).isEqualTo(700.0);
        // Only the real question's answer should have been persisted (1 call, not 2).
        verify(responses, times(1)).save(any());
    }

    @Test
    void submitThrows409WhenTheUserAlreadyWatchedThisCampaign() {
        when(history.existsByUserIdAndCampaignId(42L, 1L)).thenReturn(true);
        var ex = assertFailsWithHttp(() ->
                service.submitSurvey(42L, 1L, List.of(new SubmitSurveyReq.Answer(1L, "\"x\""))));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(campaigns, never()).tryDecrementBudget(anyLong());
    }

    @Test
    void submitThrows404WhenTheCampaignDoesNotExist() {
        when(history.existsByUserIdAndCampaignId(42L, 999L)).thenReturn(false);
        when(campaigns.findById(999L)).thenReturn(Optional.empty());
        var ex = assertFailsWithHttp(() ->
                service.submitSurvey(42L, 999L, List.of(new SubmitSurveyReq.Answer(1L, "\"x\""))));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void submitThrows409WhenTryDecrementBudgetReturns0() {
        when(history.existsByUserIdAndCampaignId(42L, 1L)).thenReturn(false);
        when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1)));
        when(campaigns.tryDecrementBudget(1L)).thenReturn(0);

        var ex = assertFailsWithHttp(() ->
                service.submitSurvey(42L, 1L, List.of(new SubmitSurveyReq.Answer(1L, "\"x\""))));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        // No view_history or balance mutation should have happened.
        verify(history, never()).save(any());
        verify(users, never()).save(any());
    }
}
