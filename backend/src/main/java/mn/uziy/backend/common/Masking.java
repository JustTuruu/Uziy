package mn.uziy.backend.common;

import org.jspecify.annotations.Nullable;

/** Hides most of an identifier (a bank account, a phone number) so a screen can show which one without what it is. */
public final class Masking {

    /** How many trailing characters stay readable. */
    public static final int VISIBLE_TAIL = 4;
    static final String HIDDEN = "••••";

    private Masking() {
    }

    /**
     * {@code "5012345678"} → {@code "•••• 5678"}. A value of {@value #VISIBLE_TAIL} characters or fewer is hidden
     * completely: showing all of it would be no mask at all.
     */
    public static String lastFour(@Nullable String value) {
        if (value == null) {
            return HIDDEN;
        }
        String trimmed = value.strip();
        if (trimmed.length() <= VISIBLE_TAIL) {
            return HIDDEN;
        }
        return HIDDEN + " " + trimmed.substring(trimmed.length() - VISIBLE_TAIL);
    }
}
