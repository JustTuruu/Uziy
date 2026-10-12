package mn.uziy.backend.company;

import java.util.List;

/**
 * The fixed answers of a RATING question, worst to best. The company never types them: every rating
 * question offers exactly these, so answers from different campaigns mean the same thing and the
 * existing choice counting (analytics) works without a special case.
 */
public final class RatingScale {

    public static final String TYPE = "RATING";

    public static final List<String> LABELS = List.of("Муу", "Дунд", "Сайн");

    private RatingScale() {
    }
}
