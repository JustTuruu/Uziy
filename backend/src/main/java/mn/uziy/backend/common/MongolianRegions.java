package mn.uziy.backend.common;

import java.util.List;
import java.util.Set;
import java.util.stream.Stream;

/**
 * Where a viewer lives: the capital or one of the 21 aimags, and in the capital one of its 9 districts. These
 * exact strings are a contract — a campaign's {@code targetCity} matches a viewer's {@code city} character for
 * character — so the viewer app and the company panel offer this same list (keep all three in step).
 */
public final class MongolianRegions {

    public static final String CAPITAL = "Улаанбаатар";

    /** A campaign's {@code targetCity} for "every place". */
    public static final String EVERYWHERE = "ALL";

    /** The 21 aimags, in Mongolian alphabetical order. */
    public static final List<String> AIMAGS = List.of(
            "Архангай", "Баян-Өлгий", "Баянхонгор", "Булган", "Говь-Алтай", "Говьсүмбэр", "Дархан-Уул",
            "Дорноговь", "Дорнод", "Дундговь", "Завхан", "Орхон", "Өвөрхангай", "Өмнөговь", "Сүхбаатар",
            "Сэлэнгэ", "Төв", "Увс", "Ховд", "Хөвсгөл", "Хэнтий");

    /** The capital's 9 districts (дүүрэг). */
    public static final List<String> CAPITAL_DISTRICTS = List.of(
            "Багануур", "Багахангай", "Баянгол", "Баянзүрх", "Налайх", "Сонгинохайрхан", "Сүхбаатар", "Хан-Уул",
            "Чингэлтэй");

    private static final Set<String> CITIES =
            Set.copyOf(Stream.concat(Stream.of(CAPITAL), AIMAGS.stream()).toList());
    private static final Set<String> DISTRICTS = Set.copyOf(CAPITAL_DISTRICTS);

    private MongolianRegions() {
    }

    /** The capital or an aimag, spelled exactly as listed. */
    public static boolean isCity(String value) {
        return CITIES.contains(value);
    }

    /** What a campaign may target: {@link #EVERYWHERE} or one city from the list. */
    public static boolean isTargetCity(String value) {
        return EVERYWHERE.equals(value) || isCity(value);
    }

    public static boolean isCapitalDistrict(String value) {
        return DISTRICTS.contains(value);
    }
}
