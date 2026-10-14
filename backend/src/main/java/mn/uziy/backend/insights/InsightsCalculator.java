package mn.uziy.backend.insights;

import java.time.LocalDate;
import java.time.Period;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import mn.uziy.backend.analytics.AgeBands;
import mn.uziy.backend.analytics.AnswerCounter;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.Group;
import mn.uziy.backend.insights.InsightsDtos.OptionShare;
import mn.uziy.backend.insights.InsightsRepository.Answer;
import mn.uziy.backend.insights.InsightsRepository.Person;
import org.jspecify.annotations.Nullable;

/** Pure maths of the statistics: grouping people, counting answers, applying {@link StatisticsPrivacyPolicy}. */
final class InsightsCalculator {

    static final String MALE = "MALE";
    static final String FEMALE = "FEMALE";
    static final Map<String, String> GENDER_LABELS = Map.of(MALE, "Эрэгтэй", FEMALE, "Эмэгтэй");

    private InsightsCalculator() {
    }

    static @Nullable String ageBand(Person p, LocalDate today) {
        LocalDate born = p.birthDate();
        return born == null ? null : AgeBands.labelOf(Period.between(born, today).getYears());
    }

    static boolean matches(Person p, Filter f, LocalDate today) {
        return (f.gender() == null || f.gender().equals(p.gender()))
                && (f.ageBand() == null || f.ageBand().equals(ageBand(p, today)))
                && (f.city() == null || f.city().equals(p.city()));
    }

    /** People per value of {@code key}, in {@code order}; groups under the minimum show no number. */
    static List<Group> groups(List<Person> people, Function<Person, @Nullable String> key, List<String> order,
                              Function<String, String> label) {
        Map<String, Long> counts = new LinkedHashMap<>();
        for (Person p : people) {
            String value = key.apply(p);
            if (value != null) {
                counts.merge(value, 1L, Long::sum);
            }
        }
        List<Group> out = new ArrayList<>();
        for (String value : order) {
            long n = counts.getOrDefault(value, 0L);
            out.add(new Group(label.apply(value),
                    StatisticsPrivacyPolicy.reportable(n) ? StatisticsPrivacyPolicy.roundedCount(n) : null));
        }
        return out;
    }

    /** Share of {@code answers} that picked each option (a multiple choice may add up to more than 100). */
    static List<OptionShare> shares(List<String> options, List<Answer> answers) {
        Map<String, Long> picked = new LinkedHashMap<>();
        options.forEach(o -> picked.put(o, 0L));
        for (Answer a : answers) {
            for (String choice : AnswerCounter.strings(a.answerJson())) {
                picked.computeIfPresent(choice, (k, n) -> n + 1);
            }
        }
        List<OptionShare> out = new ArrayList<>();
        picked.forEach((option, n) ->
                out.add(new OptionShare(option, StatisticsPrivacyPolicy.percent(n, answers.size()))));
        return out;
    }

    static List<String> options(String optionsJson) {
        return AnswerCounter.strings(optionsJson);
    }

    static String describe(Filter f) {
        return "gender=" + Objects.toString(f.gender(), "*") + " ageBand=" + Objects.toString(f.ageBand(), "*")
                + " city=" + Objects.toString(f.city(), "*");
    }
}
