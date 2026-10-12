package mn.uziy.backend.viewer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.common.ConflictException;
import org.junit.jupiter.api.Test;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataIntegrityViolationException;

class RetryingRewardServiceTest {

    private final RewardService delegate = mock(RewardService.class);
    private final RetryingRewardService service = new RetryingRewardService(delegate);
    private final List<SubmitSurveyReq.Answer> answers = List.of(new SubmitSurveyReq.Answer(1L, "\"x\""));
    private final RewardResult paid = new RewardResult(700, 700);

    @Test
    void aCleanRunIsReturnedAsIs() {
        when(delegate.submitSurvey(1L, 2L, answers)).thenReturn(paid);

        assertThat(service.submitSurvey(1L, 2L, answers)).isSameAs(paid);
        verify(delegate, times(1)).submitSurvey(1L, 2L, answers);
    }

    @Test
    void aRaceWithAnotherTransactionIsRetriedUntilItGoesThrough() {
        when(delegate.submitSurvey(1L, 2L, answers))
                .thenThrow(new CannotAcquireLockException("serialization failure"))
                .thenThrow(new CannotAcquireLockException("serialization failure"))
                .thenReturn(paid);

        assertThat(service.submitSurvey(1L, 2L, answers)).isSameAs(paid);
        verify(delegate, times(3)).submitSurvey(1L, 2L, answers);
    }

    @Test
    void persistentContentionBecomesABusyConflictNotAServerError() {
        when(delegate.submitSurvey(anyLong(), anyLong(), any()))
                .thenThrow(new CannotAcquireLockException("serialization failure"));

        assertThatThrownBy(() -> service.submitSurvey(1L, 2L, answers))
                .isInstanceOf(ConflictException.class).hasMessage(RetryingRewardService.BUSY);
        verify(delegate, times(RetryingRewardService.MAX_ATTEMPTS)).submitSurvey(1L, 2L, answers);
    }

    @Test
    void businessRefusalsAreNeverRetried() {
        when(delegate.submitSurvey(1L, 2L, answers)).thenThrow(new ConflictException("Already rewarded"));

        assertThatThrownBy(() -> service.submitSurvey(1L, 2L, answers)).isInstanceOf(ConflictException.class);
        verify(delegate, times(1)).submitSurvey(1L, 2L, answers);
    }

    @Test
    void otherErrorsAreNotSwallowedOrRetried() {
        when(delegate.submitSurvey(1L, 2L, answers)).thenThrow(new DataIntegrityViolationException("x"));

        assertThatThrownBy(() -> service.submitSurvey(1L, 2L, answers))
                .isInstanceOf(DataIntegrityViolationException.class);
        verify(delegate, times(1)).submitSurvey(1L, 2L, answers);
    }
}
