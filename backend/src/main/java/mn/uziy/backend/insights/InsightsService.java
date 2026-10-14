package mn.uziy.backend.insights;

import java.util.List;
import mn.uziy.backend.insights.InsightsDtos.AccessLogEntry;
import mn.uziy.backend.insights.InsightsDtos.Distribution;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.Overview;
import mn.uziy.backend.insights.InsightsDtos.QuestionSummary;
import mn.uziy.backend.insights.InsightsDtos.Segments;

/**
 * The super admin's anonymous statistics across all surveys. Every method records who asked
 * (data_access_log) and follows {@link StatisticsPrivacyPolicy}.
 */
public interface InsightsService {

    String TEXT_NOT_ALLOWED = "Чөлөөт текст хариулт статистикт ордоггүй";
    String UNKNOWN_FILTER = "Шүүлтүүрийн утга буруу байна";
    String QUESTION_NOT_FOUND = "Асуулт олдсонгүй";

    Overview overview(long adminId);

    List<QuestionSummary> questions(long adminId);

    /**
     * @throws mn.uziy.backend.common.NotFoundException for an unknown question
     * @throws mn.uziy.backend.common.BadRequestException for a free-text question or an unknown filter value
     */
    Distribution distribution(long adminId, long questionId, Filter filter);

    /** By gender and by age band; rules as {@link #distribution}. */
    Segments segments(long adminId, long questionId);

    /** The segments as a CSV file (UTF-8 with BOM, opens in Excel); recorded as an export. */
    String exportCsv(long adminId, long questionId);

    List<AccessLogEntry> accessLog(long adminId);
}
