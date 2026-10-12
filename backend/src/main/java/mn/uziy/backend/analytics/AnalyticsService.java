package mn.uziy.backend.analytics;

import mn.uziy.backend.analytics.AnalyticsDtos.AnalyticsResponse;
import org.jspecify.annotations.Nullable;

/** Read-only performance reporting for a company's campaigns. */
public interface AnalyticsService {

    int MIN_DAYS = 7;
    int MAX_DAYS = 90;
    int DEFAULT_DAYS = 30;

    /** Fewer completed views than this and the audience breakdown is withheld, so a viewer cannot be picked out. */
    int MIN_AUDIENCE_SAMPLE = 5;

    int MAX_CITIES = 8;

    /** A segment (e.g. women 25–34) needs at least this many answerers before its answers are shown. */
    int MIN_SEGMENT_SAMPLE = 5;

    /** The recent pace behind "days left" is the average of this many days. */
    int PACE_DAYS = 7;

    /**
     * @param days window of the daily series, {@link #MIN_DAYS}..{@link #MAX_DAYS}
     * @param campaignId limits the daily series, audience and question results to one campaign
     *        (the comparison table and totals always cover all)
     * @throws mn.uziy.backend.common.BadRequestException for a {@code days} outside the range
     * @throws mn.uziy.backend.common.NotFoundException when {@code campaignId} is not the company's
     */
    AnalyticsResponse analytics(long companyId, int days, @Nullable Long campaignId);
}
