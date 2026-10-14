package mn.uziy.backend.insights;

import java.time.OffsetDateTime;
import java.util.List;
import org.jspecify.annotations.Nullable;

/** What the super admin's statistics pages receive. Never a person — only groups that passed the policy. */
public final class InsightsDtos {

    private InsightsDtos() {
    }

    /** One group (e.g. "Эмэгтэй", "25–34", "Дархан-Уул"); {@code people} is null when it is too small to show. */
    public record Group(String label, @Nullable Long people) {
    }

    public record Overview(
            int minGroupSize,
            long viewers,
            long consentingViewers,
            int consentPercent,
            List<Group> byGender,
            List<Group> byAgeBand,
            List<Group> byCity,
            long reportableQuestions) {
    }

    /** A choice or rating question that statistics can be made of; {@code respondents} counts consenting viewers. */
    public record QuestionSummary(
            long questionId,
            String prompt,
            String type,
            String surveyTitle,
            String companyName,
            long respondents,
            boolean reportable) {
    }

    /** The filters a distribution was made for; null = any. */
    public record Filter(@Nullable String gender, @Nullable String ageBand, @Nullable String city) {
    }

    /** Share of the group that picked one option. */
    public record OptionShare(String option, int percent) {
    }

    /**
     * Answers of one group. When {@code suppressed} the group is under the minimum: {@code people} is null and
     * {@code shares} is empty.
     */
    public record Distribution(
            long questionId,
            String prompt,
            String type,
            Filter filter,
            boolean suppressed,
            @Nullable Long people,
            List<OptionShare> shares) {
    }

    /** One segment row: same shape as a distribution, labelled by dimension and value. */
    public record SegmentRow(String dimension, String label, boolean suppressed, @Nullable Long people,
                             List<OptionShare> shares) {
    }

    public record Segments(long questionId, String prompt, List<String> options, List<SegmentRow> rows) {
    }

    public record AccessLogEntry(long id, String adminPhone, String action, String detail, OffsetDateTime at) {
    }
}
