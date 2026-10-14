package mn.uziy.backend.insights;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.Group;
import mn.uziy.backend.insights.InsightsDtos.OptionShare;
import mn.uziy.backend.insights.InsightsRepository.Answer;
import mn.uziy.backend.insights.InsightsRepository.Person;
import org.junit.jupiter.api.Test;

class InsightsCalculatorTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 14);

    private static Person person(String gender, int age, String city) {
        return new Person(gender, TODAY.minusYears(age), city);
    }

    private static List<Person> many(int n, Person p) {
        List<Person> out = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            out.add(p);
        }
        return out;
    }

    @Test
    void ageBandFollowsTheBirthDateAndIsUnknownWithoutOne() {
        assertThat(InsightsCalculator.ageBand(person("MALE", 30, "Ховд"), TODAY)).isEqualTo("25–34");
        assertThat(InsightsCalculator.ageBand(new Person("MALE", null, "Ховд"), TODAY)).isNull();
    }

    @Test
    void groupsUnderTheMinimumShowNoNumberAndBigOnesAreRounded() {
        List<Person> people = new ArrayList<>(many(57, person("FEMALE", 30, "Ховд")));
        people.addAll(many(12, person("MALE", 30, "Ховд")));

        List<Group> groups = InsightsCalculator.groups(people, Person::gender, List.of("MALE", "FEMALE"),
                InsightsCalculator.GENDER_LABELS::get);

        assertThat(groups).containsExactly(new Group("Эрэгтэй", null), new Group("Эмэгтэй", 50L));
    }

    @Test
    void sharesCountEveryPickedOptionAndIgnoreUnknownOnes() {
        List<Answer> answers = List.of(
                new Answer("[\"A\",\"B\"]", person("MALE", 30, "Ховд")),
                new Answer("\"A\"", person("MALE", 30, "Ховд")),
                new Answer("\"Z\"", person("MALE", 30, "Ховд")),
                new Answer("not json", person("MALE", 30, "Ховд")));

        List<OptionShare> shares = InsightsCalculator.shares(List.of("A", "B", "C"), answers);

        assertThat(shares).containsExactly(new OptionShare("A", 50), new OptionShare("B", 25),
                new OptionShare("C", 0));
    }

    @Test
    void aFilterMatchesOnlyItsGroupAndNullMeansAny() {
        Person woman30Hovd = person("FEMALE", 30, "Ховд");

        assertThat(InsightsCalculator.matches(woman30Hovd, new Filter(null, null, null), TODAY)).isTrue();
        assertThat(InsightsCalculator.matches(woman30Hovd, new Filter("FEMALE", "25–34", "Ховд"), TODAY)).isTrue();
        assertThat(InsightsCalculator.matches(woman30Hovd, new Filter("MALE", null, null), TODAY)).isFalse();
        assertThat(InsightsCalculator.matches(woman30Hovd, new Filter(null, "18–24", null), TODAY)).isFalse();
        assertThat(InsightsCalculator.matches(woman30Hovd, new Filter(null, null, "Увс"), TODAY)).isFalse();
    }

    @Test
    void theAuditDescriptionNamesEveryFilter() {
        assertThat(InsightsCalculator.describe(new Filter("FEMALE", null, "Ховд")))
                .isEqualTo("gender=FEMALE ageBand=* city=Ховд");
    }
}
