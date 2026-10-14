package mn.uziy.backend.insights;

/**
 * Every protection the anonymous statistics obey, in one place (owner, 2026-10-14):
 * <ul>
 *   <li>only viewers who consented (users.stats_consent = 'GRANTED') AND are at least {@link #MIN_AGE} are counted
 *       — a minor's consent is not enough (see InsightsRepository);</li>
 *   <li>a group of fewer than {@link #MIN_GROUP_SIZE} people is never shown (no percentages, no count), so nobody
 *       can be picked out, also not by narrowing filters;</li>
 *   <li>nor is a group whose REST (everyone else who answered) is under the minimum: otherwise "all" minus
 *       "group" would reveal those few people's answers by subtraction;</li>
 *   <li>group sizes are shown rounded down to {@link #COUNT_STEP}, percentages as whole numbers;</li>
 *   <li>free-text answers are never part of a statistic (they may name or describe a person);</li>
 *   <li>no name, phone, birth date or exact address ever leaves the database — only age bands, gender and aimag;</li>
 *   <li>every look and every export is written to data_access_log.</li>
 * </ul>
 */
public final class StatisticsPrivacyPolicy {

    public static final int MIN_GROUP_SIZE = 50;
    public static final int MIN_AGE = 18;
    public static final int COUNT_STEP = 10;
    static final String TEXT_TYPE = "TEXT";

    private StatisticsPrivacyPolicy() {
    }

    public static boolean reportable(long people) {
        return people >= MIN_GROUP_SIZE;
    }

    /** A {@code group} out of {@code all} answers: big enough, and leaves no small remainder to subtract. */
    public static boolean reportable(long group, long all) {
        long rest = all - group;
        return reportable(group) && (rest == 0 || reportable(rest));
    }

    /** {@code people} rounded down to the step: 57 → 50, 129 → 120. */
    public static long roundedCount(long people) {
        return people - people % COUNT_STEP;
    }

    /** Whole-number share of {@code part} in {@code whole}; 0 when there is no whole. */
    public static int percent(long part, long whole) {
        return whole <= 0 ? 0 : (int) Math.round(part * 100.0 / whole);
    }
}
