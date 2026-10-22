package mn.uziy.backend.analytics;

import java.sql.Date;
import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.analytics.AnalyticsDtos.AnalyticsResponse;
import mn.uziy.backend.analytics.AnalyticsDtos.Audience;
import mn.uziy.backend.analytics.AnalyticsDtos.CampaignPerformance;
import mn.uziy.backend.analytics.AnalyticsDtos.DailyViews;
import mn.uziy.backend.analytics.AnalyticsDtos.SegmentBreakdown;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.analytics.AnalyticsDtos.Totals;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRecentViews;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.CampaignViewStats;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import mn.uziy.backend.domain.SurveyQuestionRepository;
import mn.uziy.backend.domain.SurveyResponseRepository;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AnalyticsServiceImpl implements AnalyticsService {

    public static final String DAYS_OUT_OF_RANGE = "Хугацааг " + MIN_DAYS + "–" + MAX_DAYS + " хоногийн хооронд сонгоно уу";
    public static final String CAMPAIGN_NOT_FOUND = Messages.CAMPAIGN_NOT_FOUND;

    /** The market's calendar: a view at 23:30 Ulaanbaatar time belongs to that day, not the UTC one. */
    static final int HOURS_PER_DAY = 24;

    static final ZoneId MARKET_ZONE = ZoneId.of("Asia/Ulaanbaatar");

    private final CampaignRepository campaigns;
    private final ViewHistoryRepository views;
    private final SurveyQuestionRepository questions;
    private final SurveyResponseRepository responses;
    private final AnswerCounter answerCounter;
    private final SegmentCounter segmentCounter;
    private final Clock clock;

    public AnalyticsServiceImpl(CampaignRepository campaigns, ViewHistoryRepository views,
                                SurveyQuestionRepository questions, SurveyResponseRepository responses,
                                AnswerCounter answerCounter, SegmentCounter segmentCounter, Clock clock) {
        this.segmentCounter = segmentCounter;
        this.campaigns = campaigns;
        this.views = views;
        this.questions = questions;
        this.responses = responses;
        this.answerCounter = answerCounter;
        this.clock = clock;
    }

    @Override
    @Transactional(readOnly = true)
    public AnalyticsResponse analytics(long companyId, int days, @Nullable Long campaignId) {
        if (days < MIN_DAYS || days > MAX_DAYS) {
            throw new BadRequestException(DAYS_OUT_OF_RANGE);
        }
        List<CampaignEntity> own = campaigns.findAllByCompanyIdOrderByCreatedAtDesc(companyId);
        if (campaignId != null && own.stream().noneMatch(c -> c.getId().equals(campaignId))) {
            throw new NotFoundException(CAMPAIGN_NOT_FOUND);
        }

        Map<Long, CampaignViewStats> statsById = new HashMap<>();
        for (CampaignViewStats s : views.statsByCompany(companyId)) {
            statsById.put(s.campaignId(), s);
        }
        OffsetDateTime paceSince = LocalDate.now(clock.withZone(MARKET_ZONE)).minusDays(PACE_DAYS - 1L)
                .atStartOfDay(MARKET_ZONE).toOffsetDateTime();
        Map<Long, Long> recentById = new HashMap<>();
        for (CampaignRecentViews r : views.recentByCompany(companyId, paceSince)) {
            recentById.put(r.campaignId(), r.views());
        }
        List<CampaignPerformance> performance = own.stream()
                .map(c -> performanceOf(c, statsById.get(c.getId()), recentById.getOrDefault(c.getId(), 0L)))
                .toList();

        long selectedResponses = performance.stream()
                .filter(p -> campaignId == null || p.campaignId() == campaignId)
                .mapToLong(CampaignPerformance::responses)
                .sum();

        List<SurveyQuestionEntity> chosenQuestions = campaignId == null
                ? List.of()
                : questions.findAllByCampaignIdOrderByPosition(campaignId);
        List<Object[]> answers = campaignId == null ? List.of() : responses.answersOfCampaign(campaignId);

        return new AnalyticsResponse(
                days,
                totalsOf(own, performance),
                performance,
                dailySeries(companyId, campaignId, days),
                hourlySeries(companyId, campaignId, days),
                selectedResponses >= MIN_AUDIENCE_SAMPLE ? audienceOf(companyId, campaignId, selectedResponses) : null,
                campaignId == null ? List.of() : answerCounter.count(chosenQuestions, answers, MIN_SEGMENT_SAMPLE),
                campaignId == null
                        ? List.of()
                        : segmentCounter.count(chosenQuestions, answers, MIN_SEGMENT_SAMPLE));
    }

    private CampaignPerformance performanceOf(CampaignEntity c, @Nullable CampaignViewStats stats, long recent) {
        long count = stats == null ? 0 : stats.views();
        double rewards = stats == null ? 0 : stats.rewardsPaid();
        double spent = spentOn(c);
        Integer target = c.getTargetViewers();
        Double reach = target == null || target <= 0 ? null : Math.min(100.0, count * 100.0 / target);
        long remaining = c.getCostPerView() > 0 ? (long) Math.floor(c.getRemainingBudget() / c.getCostPerView()) : 0;
        return new CampaignPerformance(c.getId(), c.getTitle(), c.getStatus(), c.hasVideo(), target, count,
                reach, spent, rewards, perResponse(spent, count), remaining, recent, daysLeft(c, remaining, recent));
    }

    /** Days until the budget runs out at the last week's pace; only for a running campaign that got responses. */
    private static @Nullable Integer daysLeft(CampaignEntity c, long remainingResponses, long recent) {
        if (c.getStatus() != CampaignStatus.ACTIVE || recent == 0) {
            return null;
        }
        double perDay = recent / (double) PACE_DAYS;
        return (int) Math.ceil(remainingResponses / perDay);
    }

    /** What the company has actually used up: the budget spent so far, zero until the campaign is paid. */
    private static double spentOn(CampaignEntity c) {
        return c.getPaidAt() == null && c.getStatus() == CampaignStatus.AWAITING_PAYMENT
                ? 0.0
                : c.getTotalBudget() - c.getRemainingBudget();
    }

    private static @Nullable Double perResponse(double spent, long responses) {
        return responses == 0 ? null : spent / responses;
    }

    private Totals totalsOf(List<CampaignEntity> own, List<CampaignPerformance> performance) {
        long responseCount = performance.stream().mapToLong(CampaignPerformance::responses).sum();
        double rewards = performance.stream().mapToDouble(CampaignPerformance::rewardsPaid).sum();
        double spent = performance.stream().mapToDouble(CampaignPerformance::spent).sum();
        int active = (int) own.stream().filter(c -> c.getStatus() == CampaignStatus.ACTIVE).count();
        return new Totals(own.size(), active, responseCount, rewards, spent, perResponse(spent, responseCount));
    }

    /** One row per day of the window, today last; days without a view are zero. */
    private List<DailyViews> dailySeries(long companyId, @Nullable Long campaignId, int days) {
        LocalDate today = LocalDate.now(clock.withZone(MARKET_ZONE));
        LocalDate first = today.minusDays(days - 1L);
        OffsetDateTime since = first.atStartOfDay(MARKET_ZONE).toOffsetDateTime();

        Map<LocalDate, Long> counts = new HashMap<>();
        for (Object[] row : views.dailyCounts(companyId, campaignId, since, MARKET_ZONE.getId())) {
            counts.put(toLocalDate(row[0]), ((Number) row[1]).longValue());
        }
        List<DailyViews> out = new ArrayList<>();
        for (LocalDate d = first; !d.isAfter(today); d = d.plusDays(1)) {
            out.add(new DailyViews(d, counts.getOrDefault(d, 0L)));
        }
        return out;
    }

    /** A native `date` column arrives as {@link LocalDate} (Hibernate 7) or, on older setups, {@link Date}. */
    static LocalDate toLocalDate(Object value) {
        return value instanceof Date sqlDate ? sqlDate.toLocalDate() : (LocalDate) value;
    }

    /**
     * Each dimension is cut by {@link SmallGroupRule} against {@code responses}, the total the company already
     * sees, so no slice of fewer than {@link #MIN_AUDIENCE_SAMPLE} people can be read off or subtracted out.
     */
    private Audience audienceOf(long companyId, @Nullable Long campaignId, long responses) {
        List<Slice> gender = new ArrayList<>();
        for (Object[] row : views.genderCounts(companyId, campaignId)) {
            gender.add(new Slice((String) row[0], ((Number) row[1]).longValue()));
        }
        Map<Integer, Long> byAge = new LinkedHashMap<>();
        for (Object[] row : views.ageCounts(companyId, campaignId)) {
            byAge.put(((Number) row[0]).intValue(), ((Number) row[1]).longValue());
        }
        List<Slice> cities = new ArrayList<>();
        for (Object[] row : views.cityCounts(companyId, campaignId)) {
            cities.add(new Slice((String) row[0], ((Number) row[1]).longValue()));
        }
        // Cut before keeping the biggest: the cities left off the list only add to the hidden rest.
        List<Slice> shownCities = SmallGroupRule.reportable(cities, responses, MIN_AUDIENCE_SAMPLE);
        return new Audience(
                SmallGroupRule.reportable(gender, responses, MIN_AUDIENCE_SAMPLE),
                SmallGroupRule.reportable(AgeBands.group(byAge), responses, MIN_AUDIENCE_SAMPLE),
                shownCities.subList(0, Math.min(MAX_CITIES, shownCities.size())));
    }

    /** Responses per hour of the day (index = hour, 24 entries) over the window, in market time. */
    private List<Long> hourlySeries(long companyId, @Nullable Long campaignId, int days) {
        LocalDate first = LocalDate.now(clock.withZone(MARKET_ZONE)).minusDays(days - 1L);
        OffsetDateTime since = first.atStartOfDay(MARKET_ZONE).toOffsetDateTime();
        long[] perHour = new long[HOURS_PER_DAY];
        for (Object[] row : views.hourlyCounts(companyId, campaignId, since, MARKET_ZONE.getId())) {
            perHour[((Number) row[0]).intValue()] = ((Number) row[1]).longValue();
        }
        return java.util.Arrays.stream(perHour).boxed().toList();
    }
}
