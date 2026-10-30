package mn.uziy.backend.viewer;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class QuizCheckServiceImplTest {

    private static final long CAMPAIGN = 1L;
    private static final long QUESTION = 7L;

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);
    private final QuizCheckServiceImpl service = new QuizCheckServiceImpl(campaigns, questions);

    private final CampaignEntity campaign = sampleCampaign(CAMPAIGN);

    private static SurveyQuestionEntity question(String type, long campaignId) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(QUESTION);
        q.setCampaignId(campaignId);
        q.setQType(type);
        q.setOptionsJson("[\"Улаан\",\"Цэнхэр\"]");
        q.setCorrectAnswer("QUIZ".equals(type) ? "Цэнхэр" : null);
        return q;
    }

    @BeforeEach
    void runningCampaign() {
        campaign.setStatus(CampaignStatus.ACTIVE);
        when(campaigns.findById(CAMPAIGN)).thenReturn(Optional.of(campaign));
    }

    @Test
    void theCorrectOptionIsRight() {
        when(questions.findById(QUESTION)).thenReturn(Optional.of(question("QUIZ", CAMPAIGN)));
        assertThat(service.check(CAMPAIGN, QUESTION, "Цэнхэр").correct()).isTrue();
    }

    @Test
    void anotherListedOptionIsWrong() {
        when(questions.findById(QUESTION)).thenReturn(Optional.of(question("QUIZ", CAMPAIGN)));
        assertThat(service.check(CAMPAIGN, QUESTION, "Улаан").correct()).isFalse();
    }

    @Test
    void anUnlistedAnswerIsABadRequest() {
        when(questions.findById(QUESTION)).thenReturn(Optional.of(question("QUIZ", CAMPAIGN)));
        assertThatThrownBy(() -> service.check(CAMPAIGN, QUESTION, "Ногоон"))
                .isInstanceOf(BadRequestException.class);
    }

    @Test
    void aQuestionOfAnotherCampaignOrAnotherTypeIsNotFound() {
        when(questions.findById(QUESTION)).thenReturn(Optional.of(question("QUIZ", 99L)));
        assertThatThrownBy(() -> service.check(CAMPAIGN, QUESTION, "Цэнхэр")).isInstanceOf(NotFoundException.class);

        when(questions.findById(QUESTION)).thenReturn(Optional.of(question("SINGLE_CHOICE", CAMPAIGN)));
        assertThatThrownBy(() -> service.check(CAMPAIGN, QUESTION, "Цэнхэр")).isInstanceOf(NotFoundException.class);
    }

    @Test
    void aCampaignThatIsNotRunningIsNotFound() {
        campaign.setStatus(CampaignStatus.PAUSED);
        assertThatThrownBy(() -> service.check(CAMPAIGN, QUESTION, "Цэнхэр")).isInstanceOf(NotFoundException.class);
    }
}
