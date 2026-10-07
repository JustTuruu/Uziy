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
import mn.uziy.backend.domain.ViewHistoryEntity;
import mn.uziy.backend.domain.ViewHistoryRepository;
import java.time.OffsetDateTime;
import org.springframework.data.domain.PageRequest;
import org.junit.jupiter.api.Test;

class ViewerServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);

    private final ViewHistoryRepository views = mock(ViewHistoryRepository.class);

    private final ViewerServiceImpl service = new ViewerServiceImpl(users, campaigns, questions, views,
            new mn.uziy.backend.auth.MeMapper(), new FeedItemMapper(), new QuestionMapper(),
            new ViewHistoryMapper());

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

    // ------- history -------------------------------------------------------

    private static ViewHistoryEntity view(long campaignId, double reward, OffsetDateTime at) {
        ViewHistoryEntity v = new ViewHistoryEntity();
        v.setUserId(42L);
        v.setCampaignId(campaignId);
        v.setRewardPaid(reward);
        v.setWatchedAt(at);
        return v;
    }

    private static UserEntity company(String name) {
        UserEntity company = new UserEntity();
        company.setId(500L);
        company.setCompanyName(name);
        return company;
    }

    @Test
    void historyReturnsViewsWithCampaignTitleAndCompanyNameKeepingRepositoryOrder() {
        OffsetDateTime newer = OffsetDateTime.parse("2026-10-06T10:00:00+08:00");
        OffsetDateTime older = OffsetDateTime.parse("2026-10-05T10:00:00+08:00");
        when(views.findByUserIdOrderByWatchedAtDesc(42L, PageRequest.ofSize(ViewerService.HISTORY_LIMIT)))
                .thenReturn(List.of(view(2L, 500.0, newer), view(1L, 700.0, older)));
        when(campaigns.findAllById(List.of(2L, 1L)))
                .thenReturn(List.of(sampleCampaign(1), sampleCampaign(2)));
        when(users.findAllById(List.of(500L))).thenReturn(List.of(company("MobiCom")));

        List<ViewHistoryItemDto> history = service.history(42L);

        assertThat(history).extracting(ViewHistoryItemDto::campaignId).containsExactly(2L, 1L);
        assertThat(history.get(0).rewardPaid()).isEqualTo(500.0);
        assertThat(history.get(0).watchedAt()).isEqualTo(newer);
        assertThat(history.get(0).companyName()).isEqualTo("MobiCom");
        assertThat(history.get(0).title()).isEqualTo("Test");
    }

    @Test
    void historyIsEmptyWhenTheViewerHasNotWatchedAnything() {
        when(views.findByUserIdOrderByWatchedAtDesc(42L, PageRequest.ofSize(ViewerService.HISTORY_LIMIT)))
                .thenReturn(List.of());

        assertThat(service.history(42L)).isEmpty();
    }

    @Test
    void historySkipsViewsWhoseCampaignNoLongerExists() {
        when(views.findByUserIdOrderByWatchedAtDesc(42L, PageRequest.ofSize(ViewerService.HISTORY_LIMIT)))
                .thenReturn(List.of(view(9L, 700.0, OffsetDateTime.now())));
        when(campaigns.findAllById(List.of(9L))).thenReturn(List.of());

        assertThat(service.history(42L)).isEmpty();
    }

    @Test
    void historyUsesAnEmptyCompanyNameWhenTheCompanyHasNone() {
        when(views.findByUserIdOrderByWatchedAtDesc(42L, PageRequest.ofSize(ViewerService.HISTORY_LIMIT)))
                .thenReturn(List.of(view(1L, 700.0, OffsetDateTime.now())));
        when(campaigns.findAllById(List.of(1L))).thenReturn(List.of(sampleCampaign(1)));
        when(users.findAllById(List.of(500L))).thenReturn(List.of(company(null)));

        assertThat(service.history(42L).get(0).companyName()).isEmpty();
    }
}
