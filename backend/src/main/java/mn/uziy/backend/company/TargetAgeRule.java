package mn.uziy.backend.company;

import mn.uziy.backend.common.BadRequestException;

/**
 * How narrowly a campaign may aim by age (2026-10-22 audit). One exact age in one aimag can be a handful of
 * people, and the company then sees each one's answers; so the range must span at least {@link #MIN_AGE_SPAN}
 * years. The company panel's wizard checks the same before submitting ({@code lib/targeting.ts}).
 */
public final class TargetAgeRule {

    /** {@code maxAge - minAge} must be at least this, e.g. 18–23. */
    public static final int MIN_AGE_SPAN = 5;
    public static final int LOWEST_AGE = 0;
    public static final int HIGHEST_AGE = 120;

    public static final String AGE_OUT_OF_RANGE = "Насыг " + LOWEST_AGE + "–" + HIGHEST_AGE + " хооронд оруулна уу";
    public static final String AGE_RANGE_TOO_NARROW =
            "Их нас бага наснаас дор хаяж " + MIN_AGE_SPAN + " жилээр их байх ёстой — цөөхөн хүнд чиглэсэн "
                    + "судалгаанаас хариулагч хэн болох нь танигдах эрсдэлтэй";

    private TargetAgeRule() {
    }

    /** @throws BadRequestException with one of the messages above */
    public static void check(int minAge, int maxAge) {
        if (minAge < LOWEST_AGE || maxAge > HIGHEST_AGE) {
            throw new BadRequestException(AGE_OUT_OF_RANGE);
        }
        if (maxAge - minAge < MIN_AGE_SPAN) {
            throw new BadRequestException(AGE_RANGE_TOO_NARROW);
        }
    }
}
