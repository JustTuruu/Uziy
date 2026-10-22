package mn.uziy.backend.analytics;

import static mn.uziy.backend.viewer.ViewerTestData.sampleCampaign;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.sql.Date;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.analytics.AnalyticsDtos.AnalyticsResponse;
import mn.uziy.backend.analytics.AnalyticsDtos.CampaignPerformance;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.CampaignRecentViews;
import mn.uziy.backend.domain.CampaignViewStats;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.SurveyResponseRepository;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.junit.jupiter.api.Test;

class AnalyticsServiceTest {

    private static final long COMPANY = 500L;
    /** 2026-10-07 00:30 in Ulaanbaatar (UTC+8) is still 2026-10-06 in UTC. */
    private static final Instant NOW = Instant.parse("2026-10-06T16:30:00Z");

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final ViewHistoryRepository views = mock(ViewHistoryRepository.class);
    private final SurveyQuestionRepository questions = mock(SurveyQuestionRepository.class);
    private final SurveyResponseRepository responses = mock(SurveyResponseRepository.class);
    private final AnswerCounter answerCounter = mock(AnswerCounter.class);
    private final SegmentCounter segmentCounter = mock(SegmentCounter.class);
    private final AnalyticsServiceImpl service = new AnalyticsServiceImpl(
            campaigns, views, questions, responses, answerCounter, segmentCounter,
            Clock.fixed(NOW, ZoneOffset.UTC));

    private CampaignEntity campaign(long id, double total, double remaining, Integer target) {
        CampaignEntity c = sampleCampaign(id);
        c.setTitle("c" + id);
        c.setTotalBudget(total);
        c.setRemainingBudget(remaining);
        c.setTargetViewers(target);
        c.setPaidAt(OffsetDateTime.parse("2026-10-01T00:00:00Z"));
        return c;
    }

    private void owns(CampaignEntity... list) {
        when(campaigns.findAllByCompanyIdOrderByCreatedAtDesc(COMPANY)).thenReturn(List.of(list));
    }

    private static List<Object[]> rows(Object[]... r) {
        return List.of(r);
    }

    // ------- validation ----------------------------------------------------

    @Test
    void aWindowShorterOrLongerThanAllowedIsRefused() {
        assertThatThrownBy(() -> service.analytics(COMPANY, AnalyticsService.MIN_DAYS - 1, null))
                .isInstanceOf(BadRequestException.class);
        assertThatThrownBy(() -> service.analytics(COMPANY, AnalyticsService.MAX_DAYS + 1, null))
                .isInstanceOf(BadRequestException.class);
        verify(campaigns, never()).findAllByCompanyIdOrderByCreatedAtDesc(any(Long.class));
    }

    @Test
    void anotherCompanysCampaignIsNotFound() {
        owns(campaign(1, 1000, 500, 10));

        assertThatThrownBy(() -> service.analytics(COMPANY, 30, 99L))
                .isInstanceOf(NotFoundException.class)
                .hasMessage(AnalyticsServiceImpl.CAMPAIGN_NOT_FOUND);
    }

    // ------- campaigns and totals -------------------------------------------

    @Test
    void eachCampaignGetsResponsesReachSpendAndCostPerResponse() {
        owns(campaign(1, 10_000, 6_000, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 4, 2_800.0)));

        CampaignPerformance p = service.analytics(COMPANY, 30, null).campaigns().get(0);

        assertThat(p.responses()).isEqualTo(4);
        assertThat(p.reachPercent()).isEqualTo(40.0);
        assertThat(p.spent()).isEqualTo(4_000.0);
        assertThat(p.rewardsPaid()).isEqualTo(2_800.0);
        assertThat(p.costPerResponse()).isEqualTo(1_000.0);
    }

    @Test
    void aCampaignNobodyWatchedHasZerosAndNoCostPerResponse() {
        owns(campaign(1, 10_000, 10_000, 10));

        CampaignPerformance p = service.analytics(COMPANY, 30, null).campaigns().get(0);

        assertThat(p.responses()).isZero();
        assertThat(p.reachPercent()).isZero();
        assertThat(p.costPerResponse()).isNull();
    }

    @Test
    void reachNeverExceedsOneHundredPercentAndIsUnknownWithoutATarget() {
        owns(campaign(1, 10_000, 0, 5), campaign(2, 10_000, 0, null));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(
                new CampaignViewStats(1, 9, 0), new CampaignViewStats(2, 3, 0)));

        List<CampaignPerformance> out = service.analytics(COMPANY, 30, null).campaigns();

        assertThat(out.get(0).reachPercent()).isEqualTo(100.0);
        assertThat(out.get(1).reachPercent()).isNull();
    }

    @Test
    void anUnpaidCampaignHasSpentNothing() {
        CampaignEntity unpaid = campaign(1, 10_000, 10_000, 10);
        unpaid.setStatus(CampaignStatus.AWAITING_PAYMENT);
        unpaid.setPaidAt(null);
        owns(unpaid);

        assertThat(service.analytics(COMPANY, 30, null).campaigns().get(0).spent()).isZero();
    }

    @Test
    void totalsAddUpEveryCampaignRegardlessOfTheFilter() {
        CampaignEntity paused = campaign(2, 2_000, 1_000, 2);
        paused.setStatus(CampaignStatus.PAUSED);
        owns(campaign(1, 10_000, 6_000, 10), paused);
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(
                new CampaignViewStats(1, 4, 2_800.0), new CampaignViewStats(2, 1, 700.0)));

        var totals = service.analytics(COMPANY, 30, 1L).totals();

        assertThat(totals.campaignCount()).isEqualTo(2);
        assertThat(totals.activeCount()).isEqualTo(1);
        assertThat(totals.responses()).isEqualTo(5);
        assertThat(totals.rewardsPaid()).isEqualTo(3_500.0);
        assertThat(totals.spent()).isEqualTo(5_000.0);
        assertThat(totals.costPerResponse()).isEqualTo(1_000.0);
    }

    // ------- daily series ----------------------------------------------------

    @Test
    void theDailySeriesCoversTheWindowEndingTodayInMarketTimeWithZeroFill() {
        owns(campaign(1, 1000, 500, 10));
        when(views.dailyCounts(eq(COMPANY), isNull(), any(), eq("Asia/Ulaanbaatar"))).thenReturn(
                rows(new Object[] {Date.valueOf("2026-10-07"), 3L}, new Object[] {Date.valueOf("2026-10-05"), 2L}));

        var daily = service.analytics(COMPANY, 7, null).daily();

        assertThat(daily).hasSize(7);
        assertThat(daily.get(0).date()).isEqualTo(LocalDate.parse("2026-10-01"));
        assertThat(daily.get(6).date()).isEqualTo(LocalDate.parse("2026-10-07"));
        assertThat(daily.get(6).responses()).isEqualTo(3);
        assertThat(daily.get(4).responses()).isEqualTo(2);
        assertThat(daily.get(5).responses()).isZero();
    }

    @Test
    void theWindowStartsAtMidnightOfItsFirstDayInMarketTime() {
        owns(campaign(1, 1000, 500, 10));

        service.analytics(COMPANY, 7, null);

        verify(views).dailyCounts(COMPANY, null, OffsetDateTime.parse("2026-10-01T00:00:00+08:00"), "Asia/Ulaanbaatar");
    }

    @Test
    void aDayColumnReturnedAsLocalDateIsReadToo() {
        owns(campaign(1, 1000, 500, 10));
        when(views.dailyCounts(eq(COMPANY), isNull(), any(), eq("Asia/Ulaanbaatar")))
                .thenReturn(rows(new Object[] {LocalDate.parse("2026-10-07"), 4L}));

        assertThat(service.analytics(COMPANY, 7, null).daily().get(6).responses()).isEqualTo(4);
    }

    // ------- audience --------------------------------------------------------

    @Test
    void theAudienceIsWithheldBelowTheAnonymityThreshold() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(
                List.of(new CampaignViewStats(1, AnalyticsService.MIN_AUDIENCE_SAMPLE - 1L, 0)));

        assertThat(service.analytics(COMPANY, 30, null).audience()).isNull();
        verify(views, never()).genderCounts(any(Long.class), any());
    }

    @Test
    void theAudienceIsBuiltOnceThereAreEnoughResponses() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 12, 0)));
        when(views.genderCounts(COMPANY, null)).thenReturn(
                rows(new Object[] {"MALE", 7L}, new Object[] {"FEMALE", 5L}));
        when(views.ageCounts(COMPANY, null)).thenReturn(
                rows(new Object[] {20, 6L}, new Object[] {50, 6L}));
        when(views.cityCounts(COMPANY, null)).thenReturn(rows(new Object[] {"Улаанбаатар", 12L}));

        var audience = service.analytics(COMPANY, 30, null).audience();

        assertThat(audience.gender()).containsExactly(new Slice("MALE", 7), new Slice("FEMALE", 5));
        assertThat(audience.ageBands()).containsExactly(
                new Slice("13–17", 0), new Slice("18–24", 6), new Slice("25–34", 0),
                new Slice("35–44", 0), new Slice("45+", 6));
        assertThat(audience.cities()).containsExactly(new Slice("Улаанбаатар", 12));
    }

    /**
     * Regression (2026-10-22 audit): with 3 men and 2 women among 5 responses both were listed, and with
     * "MALE 20" shown and 22 responses the 2 women could be worked out. Neither can be read now.
     */
    @Test
    void aSmallGenderSliceIsHiddenAndSoIsTheOtherOneThatWouldGiveItAway() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 22, 0)));
        when(views.genderCounts(COMPANY, null)).thenReturn(
                rows(new Object[] {"MALE", 20L}, new Object[] {"FEMALE", 2L}));

        var audience = service.analytics(COMPANY, 30, null).audience();

        assertThat(audience.gender()).isEmpty();
    }

    /** Regression (2026-10-22 audit): "Говьсүмбэр: 1" was listed beside the big cities. */
    @Test
    void aCityWithOnlyAFewViewersIsNotListedNorLeftToBeSubtracted() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 31, 0)));
        when(views.cityCounts(COMPANY, null)).thenReturn(rows(
                new Object[] {"Улаанбаатар", 20L}, new Object[] {"Орхон", 10L}, new Object[] {"Говьсүмбэр", 1L}));

        var cities = service.analytics(COMPANY, 30, null).audience().cities();

        // Hiding only Говьсүмбэр would leave 31 − 20 − 10 = 1 for anyone to subtract, so Орхон goes too.
        assertThat(cities).containsExactly(new Slice("Улаанбаатар", 20));
        long hidden = 31 - cities.stream().mapToLong(Slice::count).sum();
        assertThat(hidden).isGreaterThanOrEqualTo(AnalyticsService.MIN_AUDIENCE_SAMPLE);
    }

    @Test
    void anAgeBandWithFewViewersIsHiddenWithEnoughOthersThatTheRestStaysAGroup() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 30, 0)));
        when(views.ageCounts(COMPANY, null)).thenReturn(
                rows(new Object[] {20, 20L}, new Object[] {30, 7L}, new Object[] {40, 3L}));

        var bands = service.analytics(COMPANY, 30, null).audience().ageBands();

        assertThat(bands).containsExactly(
                new Slice("13–17", 0), new Slice("18–24", 20), new Slice("45+", 0));
    }

    @Test
    void viewersWithoutAGenderStillCountTowardsTheHiddenRest() {
        owns(campaign(1, 1000, 500, 10));
        // 12 responses, but only 10 have a gender on record: the 2 others are visible as 12 − 10.
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 12, 0)));
        when(views.genderCounts(COMPANY, null)).thenReturn(
                rows(new Object[] {"MALE", 5L}, new Object[] {"FEMALE", 5L}));

        var gender = service.analytics(COMPANY, 30, null).audience().gender();

        assertThat(gender).hasSize(1);
        assertThat(12 - gender.get(0).count()).isGreaterThanOrEqualTo(AnalyticsService.MIN_AUDIENCE_SAMPLE);
    }

    @Test
    void onlyTheBiggestCitiesAreListed() {
        owns(campaign(1, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(new CampaignViewStats(1, 200, 0)));
        List<Object[]> many = new ArrayList<>();
        for (int i = 0; i < AnalyticsService.MAX_CITIES + 3; i++) {
            many.add(new Object[] {"city" + i, 20L - i});
        }
        when(views.cityCounts(COMPANY, null)).thenReturn(many);

        assertThat(service.analytics(COMPANY, 30, null).audience().cities()).hasSize(AnalyticsService.MAX_CITIES);
    }

    @Test
    void theAudienceOfOneCampaignUsesOnlyThatCampaignsResponseCount() {
        owns(campaign(1, 1000, 500, 10), campaign(2, 1000, 500, 10));
        when(views.statsByCompany(COMPANY)).thenReturn(List.of(
                new CampaignViewStats(1, 2, 0), new CampaignViewStats(2, 50, 0)));

        assertThat(service.analytics(COMPANY, 30, 1L).audience()).isNull();
    }

    // ------- questions -------------------------------------------------------

    @Test
    void questionResultsComeOnlyWithASelectedCampaign() {
        owns(campaign(1, 1000, 500, 10));
        var breakdown = new AnalyticsDtos.QuestionBreakdown(7, "q", "TEXT", 0, List.of());
        when(questions.findAllByCampaignIdOrderByPosition(1L)).thenReturn(List.of());
        when(responses.answersOfCampaign(1L)).thenReturn(List.of());
        when(answerCounter.count(List.of(), List.of(), AnalyticsService.MIN_SEGMENT_SAMPLE))
                .thenReturn(List.of(breakdown));

        AnalyticsResponse all = service.analytics(COMPANY, 30, null);
        AnalyticsResponse one = service.analytics(COMPANY, 30, 1L);

        assertThat(all.questions()).isEmpty();
        assertThat(one.questions()).containsExactly(breakdown);
    }

    @Test
    void segmentResultsAreBuiltFromTheSameAnswersWithTheMinimumSegmentSize() {
        owns(campaign(1, 1000, 500, 10));
        List<Object[]> answers = List.<Object[]>of(new Object[] {7L, "\"A\"", "MALE", 25});
        when(responses.answersOfCampaign(1L)).thenReturn(answers);
        var segments = List.of(new AnalyticsDtos.SegmentBreakdown(7, "q", List.of(), List.of()));
        when(segmentCounter.count(any(), eq(answers), eq(AnalyticsService.MIN_SEGMENT_SAMPLE)))
                .thenReturn(segments);

        assertThat(service.analytics(COMPANY, 30, 1L).segments()).isEqualTo(segments);
        assertThat(service.analytics(COMPANY, 30, null).segments()).isEmpty();
    }

    // ------- hours and pace --------------------------------------------------

    @Test
    void theHourlySeriesAlwaysHasTwentyFourHoursWithZeroFill() {
        owns(campaign(1, 1000, 500, 10));
        when(views.hourlyCounts(eq(COMPANY), isNull(), any(), eq("Asia/Ulaanbaatar"))).thenReturn(
                rows(new Object[] {19, 5L}, new Object[] {0, 2L}));

        List<Long> hourly = service.analytics(COMPANY, 30, null).hourly();

        assertThat(hourly).hasSize(24);
        assertThat(hourly.get(19)).isEqualTo(5);
        assertThat(hourly.get(0)).isEqualTo(2);
        assertThat(hourly.get(12)).isZero();
    }

    @Test
    void aRunningCampaignKnowsHowManyResponsesAreLeftAndHowLongTheyLast() {
        CampaignEntity c = campaign(1, 10_000, 4_000, 10); // cost 1000 → 4 responses left
        owns(c);
        // 14 responses in the last 7 days = 2 a day → 2 days left
        when(views.recentByCompany(eq(COMPANY), any())).thenReturn(List.of(new CampaignRecentViews(1, 14)));

        CampaignPerformance p = service.analytics(COMPANY, 30, null).campaigns().get(0);

        assertThat(p.remainingResponses()).isEqualTo(4);
        assertThat(p.responsesLast7Days()).isEqualTo(14);
        assertThat(p.daysLeft()).isEqualTo(2);
    }

    @Test
    void daysLeftRoundsUp() {
        owns(campaign(1, 10_000, 5_000, 10)); // 5 left
        when(views.recentByCompany(eq(COMPANY), any())).thenReturn(List.of(new CampaignRecentViews(1, 14)));

        assertThat(service.analytics(COMPANY, 30, null).campaigns().get(0).daysLeft()).isEqualTo(3);
    }

    @Test
    void thereIsNoForecastWithoutRecentResponsesOrForAPausedCampaign() {
        CampaignEntity paused = campaign(2, 10_000, 4_000, 10);
        paused.setStatus(CampaignStatus.PAUSED);
        owns(campaign(1, 10_000, 4_000, 10), paused);
        when(views.recentByCompany(eq(COMPANY), any())).thenReturn(List.of(new CampaignRecentViews(2, 14)));

        List<CampaignPerformance> out = service.analytics(COMPANY, 30, null).campaigns();

        assertThat(out.get(0).daysLeft()).isNull(); // active but nothing recent
        assertThat(out.get(1).daysLeft()).isNull(); // paused
    }

    @Test
    void thePaceWindowIsTheLastSevenMarketDaysIncludingToday() {
        owns(campaign(1, 1000, 500, 10));

        service.analytics(COMPANY, 30, null);

        verify(views).recentByCompany(COMPANY, OffsetDateTime.parse("2026-10-01T00:00:00+08:00"));
    }
}
