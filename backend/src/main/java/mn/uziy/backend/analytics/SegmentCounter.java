package mn.uziy.backend.analytics;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.analytics.AnalyticsDtos.OptionBySegment;
import mn.uziy.backend.analytics.AnalyticsDtos.SegmentBreakdown;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;
import mn.uziy.backend.domain.SurveyQuestionEntity;
import org.springframework.stereotype.Component;

/**
 * How each segment (men, women, each age band) answered a choice question, so an advertiser can see
 * who liked the offer. A segment smaller than the minimum is left out entirely rather than shown,
 * and so is one whose leftover could be subtracted from the question's totals, so a handful of answers
 * can never point at one person.
 */
@Component
public class SegmentCounter {

    static final String MALE = "MALE";
    static final String FEMALE = "FEMALE";

    private static final List<String> GENDERS = List.of(MALE, FEMALE);

    /**
     * @param answers rows of [question id, answer JSON text, gender or null, age or null]
     * @param minSegmentSample smallest number of answerers a segment needs to be reported
     */
    public List<SegmentBreakdown> count(List<SurveyQuestionEntity> questions, List<Object[]> answers,
                                        int minSegmentSample) {
        Map<Long, List<Object[]>> byQuestion = new LinkedHashMap<>();
        for (Object[] row : answers) {
            byQuestion.computeIfAbsent(((Number) row[0]).longValue(), k -> new ArrayList<>()).add(row);
        }
        List<SegmentBreakdown> out = new ArrayList<>();
        for (SurveyQuestionEntity q : questions) {
            if (AnswerCounter.TEXT.equals(q.getQType())) {
                continue;
            }
            SegmentBreakdown breakdown = breakdownOf(q, byQuestion.getOrDefault(q.getId(), List.of()),
                    minSegmentSample);
            if (breakdown != null) {
                out.add(breakdown);
            }
        }
        return out;
    }

    private SegmentBreakdown breakdownOf(SurveyQuestionEntity q, List<Object[]> rows, int minSample) {
        List<String> options = AnswerCounter.strings(q.getOptionsJson());
        // segment → answerers, and segment → option → picks, both in a stable order
        Map<String, Long> answerers = new LinkedHashMap<>();
        Map<String, Map<String, Long>> picks = new LinkedHashMap<>();
        for (Object[] row : rows) {
            List<String> chosen = AnswerCounter.strings((String) row[1]);
            for (String segment : segmentsOf((String) row[2], (Number) row[3])) {
                answerers.merge(segment, 1L, Long::sum);
                Map<String, Long> forSegment = picks.computeIfAbsent(segment, k -> new LinkedHashMap<>());
                for (String option : chosen) {
                    forSegment.merge(option, 1L, Long::sum);
                }
            }
        }

        long answered = rows.size();
        List<Slice> segments = new ArrayList<>();
        segments.addAll(reportable(GENDERS, answerers, answered, minSample));
        segments.addAll(reportable(AgeBands.labels(), answerers, answered, minSample));
        if (segments.isEmpty() || options.isEmpty()) {
            return null;
        }
        List<String> kept = segments.stream().map(Slice::label).toList();
        List<OptionBySegment> rowsOut = new ArrayList<>();
        for (String option : options) {
            List<Long> counts = kept.stream()
                    .map(s -> picks.getOrDefault(s, Map.of()).getOrDefault(option, 0L))
                    .toList();
            rowsOut.add(new OptionBySegment(option, counts));
        }
        return new SegmentBreakdown(q.getId(), q.getPrompt(), segments, rowsOut);
    }

    /** Every segment a respondent belongs to: their gender and their age band (whichever are known). */
    private static List<String> segmentsOf(String gender, Number age) {
        List<String> segments = new ArrayList<>();
        if (gender != null) {
            segments.add(gender);
        }
        if (age != null) {
            segments.add(AgeBands.labelOf(age.intValue()));
        }
        return segments;
    }

    /**
     * The segments of one dimension (genders, or age bands) that can be shown. The question's answer count and
     * option totals are public, so a segment is also withheld when the rest of its dimension would be small
     * enough to work out by subtraction ({@link SmallGroupRule}). A segment nobody is in is not a segment here.
     */
    private static List<Slice> reportable(List<String> dimension, Map<String, Long> answerers, long answered,
                                          int minSample) {
        List<Slice> present = dimension.stream()
                .filter(answerers::containsKey)
                .map(s -> new Slice(s, answerers.get(s)))
                .toList();
        return SmallGroupRule.reportable(present, answered, minSample);
    }
}
