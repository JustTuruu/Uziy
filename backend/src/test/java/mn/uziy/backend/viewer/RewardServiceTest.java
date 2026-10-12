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
import mn.uziy.backend.common.event.DomainEventPublisher;
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

    private final DomainEventPublisher events = mock(DomainEventPublisher.class);

    private final RewardServiceImpl service =
            new RewardServiceImpl(users, campaigns, questions, history, responses, events,
                    new AnswerValidator());

    private final UserEntity viewer = viewer();

    private SurveyQuestionEntity question(long id, String type, String optionsJson, boolean required) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(id);
        q.setCampaignId(1L);
        q.setPosition((int) id);
        q.setPrompt("P");
        q.setQType(type);
        q.setOptionsJson(optionsJson);
        q.setRequired(required);
        return q;
    }

    /** A running campaign for the standard viewer, with one required choice question (id 10). */
    private void aPayableCampaign() {
        when(history.existsByUserIdAndCampaignId(42L, 1L)).thenReturn(false);
        when(campaigns.findById(1L)).thenReturn(Optional.of(sampleCampaign(1)));
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(questions.findAllByCampaignIdOrderByPosition(1L))
                .thenReturn(List.of(question(10L, "SINGLE_CHOICE", "[\"Тийм\",\"Үгүй\"]", true)));
        when(campaigns.tryDecrementBudget(1L)).thenReturn(1);
        ViewHistoryEntity savedView = new ViewHistoryEntity();
        savedView.setId(999L);
        savedView.setUserId(42L);
        savedView.setCampaignId(1L);
        savedView.setRewardPaid(700.0);
        when(history.save(any())).thenReturn(savedView);
        when(responses.save(any())).thenAnswer(inv -> inv.getArgument(0));
        when(users.currentBalance(42L)).thenReturn(Optional.of(700.0));
    }

    private static List<SubmitSurveyReq.Answer> yes() {
        return List.of(new SubmitSurveyReq.Answer(10L, "\"Тийм\""));
    }

    @Test
    void submitCreditsRewardAtomicallyMarksViewAndReturnsNewBalance() {
        aPayableCampaign();

        RewardResult result = service.submitSurvey(42L, 1L, yes());

        assertThat(result.rewardPaid()).isEqualTo(700.0);
        assertThat(result.newBalance()).isEqualTo(700.0);
        verify(users).addBalance(42L, 700.0);
        verify(users, never()).save(any());
        verify(responses, times(1)).save(any());
        verify(events).publish(new RewardGranted(42L, 1L, 700.0));
    }

    @Test
    void submitStoresTheAnswerExactlyAsValidated() {
        aPayableCampaign();
        ArgumentCaptor<mn.uziy.backend.domain.SurveyResponseEntity> saved =
                ArgumentCaptor.forClass(mn.uziy.backend.domain.SurveyResponseEntity.class);
        when(responses.save(saved.capture())).thenAnswer(inv -> inv.getArgument(0));

        service.submitSurvey(42L, 1L, yes());

        assertThat(saved.getValue().getQuestionId()).isEqualTo(10L);
        assertThat(saved.getValue().getViewId()).isEqualTo(999L);
        assertThat(saved.getValue().getAnswerJson()).isEqualTo("\"Тийм\"");
    }

    @Test
    void submitRefusesAnAnswerToAQuestionOfAnotherCampaignAndPaysNothing() {
        aPayableCampaign();

        var ex = assertFailsWithHttp(() -> service.submitSurvey(42L, 1L,
                List.of(new SubmitSurveyReq.Answer(10L, "\"Тийм\""), new SubmitSurveyReq.Answer(999L, "\"x\""))));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(users, never()).addBalance(anyLong(), org.mockito.ArgumentMatchers.anyDouble());
        verify(campaigns, never()).tryDecrementBudget(anyLong());
    }

    @Test
    void submitRefusesMissingRequiredAnswersBeforeSpendingBudget() {
        aPayableCampaign();

        var ex = assertFailsWithHttp(() -> service.submitSurvey(42L, 1L,
                List.of(new SubmitSurveyReq.Answer(10L, ""))));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(campaigns, never()).tryDecrementBudget(anyLong());
        verify(history, never()).save(any());
    }

    @Test
    void submitHidesACampaignThatIsNotForThisViewer() {
        aPayableCampaign();
        var femaleOnly = sampleCampaign(1);
        femaleOnly.setTargetGender(mn.uziy.backend.domain.TargetGender.FEMALE);
        when(campaigns.findById(1L)).thenReturn(Optional.of(femaleOnly));

        var ex = assertFailsWithHttp(() -> service.submitSurvey(42L, 1L, yes()));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verify(campaigns, never()).tryDecrementBudget(anyLong());
        verify(users, never()).addBalance(anyLong(), org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void submitThrows409WhenTheUserAlreadyWatchedThisCampaign() {
        when(history.existsByUserIdAndCampaignId(42L, 1L)).thenReturn(true);
        var ex = assertFailsWithHttp(() ->
                service.submitSurvey(42L, 1L, List.of(new SubmitSurveyReq.Answer(1L, "\"x\""))));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(campaigns, never()).tryDecrementBudget(anyLong());
        verify(events, never()).publish(any());
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
        aPayableCampaign();
        when(campaigns.tryDecrementBudget(1L)).thenReturn(0);

        var ex = assertFailsWithHttp(() -> service.submitSurvey(42L, 1L, yes()));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        // No view_history or balance mutation should have happened.
        verify(history, never()).save(any());
        verify(users, never()).addBalance(anyLong(), org.mockito.ArgumentMatchers.anyDouble());
    }
}
