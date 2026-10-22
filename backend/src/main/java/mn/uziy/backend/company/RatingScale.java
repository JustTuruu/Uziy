package mn.uziy.backend.company;

import java.util.List;

/**
 * The fixed answers of a RATING question, worst to best. The company never types them: every rating
 * question offers exactly these, so answers from different campaigns mean the same thing and the
 * existing choice counting (analytics) works without a special case.
 *
 * <p>Five stops since 2026-10-21 (owner). A question is stored with the labels it was created with, so
 * older questions keep "Муу", "Дунд", "Сайн" and are still validated against those; the app draws three
 * or five faces from the labels it receives.
 */
public final class RatingScale {

    public static final String TYPE = "RATING";

    public static final List<String> LABELS = List.of("Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн");

    private RatingScale() {
    }
}
