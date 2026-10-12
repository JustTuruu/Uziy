package mn.uziy.backend.analytics;

import java.time.LocalDate;
import java.util.List;
import mn.uziy.backend.domain.CampaignStatus;
import org.jspecify.annotations.Nullable;

/** Response shapes of {@code GET /company/analytics}. All figures are aggregates; no viewer is identifiable. */
public final class AnalyticsDtos {

    private AnalyticsDtos() {
    }

    /** A labelled count (a gender, an age band, a city, an answer option). */
    public record Slice(String label, long count) {
    }

    /** Company-wide figures over every campaign, whatever the filter. */
    public record Totals(int campaignCount, int activeCount, long responses, double rewardsPaid, double spent,
                         @Nullable Double costPerResponse) {
    }

    /** One campaign's results; the comparison table is one of these per campaign. */
    public record CampaignPerformance(long campaignId, String title, CampaignStatus status, boolean hasVideo,
                                      @Nullable Integer targetViewers, long responses,
                                      @Nullable Double reachPercent, double spent, double rewardsPaid,
                                      @Nullable Double costPerResponse, long remainingResponses,
                                      long responsesLast7Days, @Nullable Integer daysLeft) {
    }

    public record DailyViews(LocalDate date, long responses) {
    }

    /** Who completed the selected campaign(s). Absent while there are too few responses to stay anonymous. */
    public record Audience(List<Slice> gender, List<Slice> ageBands, List<Slice> cities) {
    }

    /** How one survey question was answered. {@code options} is empty for free-text questions. */
    public record QuestionBreakdown(long questionId, String prompt, String type, long answered,
                                    List<Slice> options) {
    }

    /** One answer option and how many people of each segment (aligned with the breakdown's segments) chose it. */
    public record OptionBySegment(String label, List<Long> counts) {
    }

    /**
     * A choice question answered by segment: {@code segments} (label + how many answered) only holds segments
     * big enough to stay anonymous, and every option's counts line up with them.
     */
    public record SegmentBreakdown(long questionId, String prompt, List<Slice> segments,
                                   List<OptionBySegment> options) {
    }

    public record AnalyticsResponse(int days, Totals totals, List<CampaignPerformance> campaigns,
                                    List<DailyViews> daily, List<Long> hourly, @Nullable Audience audience,
                                    List<QuestionBreakdown> questions, List<SegmentBreakdown> segments) {
    }
}
