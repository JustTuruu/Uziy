package mn.uziy.backend.auth;

import java.time.LocalDate;
import mn.uziy.backend.common.BadRequestException;

/**
 * A new viewer is at least {@link #MIN_AGE} (the app's date picker enforces the same; this is the copy a direct
 * API call cannot skip, audit 2026-10-22) and the date is a real birth date: not in the future, not before
 * {@link #MAX_AGE} years ago.
 */
public final class ViewerAgeRule {

    public static final int MIN_AGE = 13;
    public static final int MAX_AGE = 120;
    public static final String TOO_YOUNG = "Бүртгүүлэхийн тулд 13 ба түүнээс дээш настай байх ёстой";
    public static final String NOT_A_BIRTH_DATE = "Төрсөн өдрөө зөв оруулна уу";

    private ViewerAgeRule() {
    }

    /** @throws BadRequestException with one of the messages above */
    public static void check(LocalDate birthDate, LocalDate today) {
        if (birthDate.isAfter(today) || birthDate.isBefore(today.minusYears(MAX_AGE))) {
            throw new BadRequestException(NOT_A_BIRTH_DATE);
        }
        if (birthDate.isAfter(today.minusYears(MIN_AGE))) {
            throw new BadRequestException(TOO_YOUNG);
        }
    }
}
