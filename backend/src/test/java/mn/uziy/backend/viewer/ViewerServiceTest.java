package mn.uziy.backend.viewer;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static mn.uziy.backend.viewer.ViewerTestData.viewer;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.TargetGender;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.Test;

class ViewerServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);

    private final ViewerServiceImpl service = new ViewerServiceImpl(users, campaigns, questions,
            new mn.uziy.backend.auth.MeMapper(), new FeedItemMapper(), new QuestionMapper());

    private final UserEntity viewer = viewer();

    private static SurveyQuestionEntity question(long id, int position, String prompt, String type,
                                                 String optionsJson, boolean required) {
        SurveyQuestionEntity q = new SurveyQuestionEntity();
        q.setId(id);
        q.setCampaignId(1L);
        q.setPosition(position);
        q.setPrompt(prompt);
        q.setQType(type);
        q.setOptionsJson(optionsJson);
        q.setRequired(required);
        return q;
    }

    // ------- me ------------------------------------------------------------

    @Test
    void meReturnsTheCurrentUser() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        Me me = service.me(42L);
        assertThat(me.id()).isEqualTo(42L);
        assertThat(me.role()).isEqualTo(Role.VIEWER);
    }

    // ------- feed ----------------------------------------------------------

    @Test
    void feedReturnsMatchingCampaignsWithCompanyNames() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(campaigns.findFeedFor(42L, TargetGender.MALE, 26, "Улаанбаатар"))
                .thenReturn(List.of(sampleCampaign(1)));
        UserEntity company = new UserEntity();
        company.setId(500L);
        company.setPhoneNumber("1");
        company.setPasswordHash("x");
        company.setRole(Role.COMPANY);
        company.setCompanyName("MobiCom");
        when(users.findAllById(List.of(500L))).thenReturn(List.of(company));

        List<FeedItemDto> feed = service.feed(42L);

        assertThat(feed).hasSize(1);
        assertThat(feed.get(0).id()).isEqualTo(1L);
        assertThat(feed.get(0).companyName()).isEqualTo("MobiCom");
    }

    @Test
    void feedReturnsEmptyWhenViewerProfileIsIncomplete() {
        viewer.setGender(null);
        viewer.setBirthDate(null);
        viewer.setCity(null);
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        assertThat(service.feed(42L)).isEmpty();
    }

    @Test
    void feedReturnsEmptyListWhenNoCampaignsMatch() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(campaigns.findFeedFor(anyLong(), any(), anyInt(), anyString())).thenReturn(List.of());
        when(users.findAllById(List.of())).thenReturn(List.of());
        assertThat(service.feed(42L)).isEmpty();
    }

    // ------- questions -----------------------------------------------------

    @Test
    void questionsReturnsOrderedSurveyQuestionsWithParsedOptions() {
        when(questions.findAllByCampaignIdOrderByPosition(1L)).thenReturn(List.of(
                question(10L, 1, "P1", "SINGLE_CHOICE", "[\"A\",\"B\",\"C\"]", true),
                question(11L, 2, "P2", "TEXT", "[]", false)));

        List<QuestionDto> qs = service.questions(1L);

        assertThat(qs).hasSize(2);
        assertThat(qs.get(0).options()).containsExactly("A", "B", "C");
        assertThat(qs.get(1).options()).isEmpty();
        assertThat(qs.get(1).type()).isEqualTo("TEXT");
    }
}
