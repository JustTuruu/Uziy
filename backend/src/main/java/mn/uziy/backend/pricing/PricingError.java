package mn.uziy.backend.pricing;

/** Error codes, in the order they are checked (first match wins). */
public enum PricingError {
    BUDGET_INVALID,
    VIEWERS_INVALID,
    REWARD_INVALID,
    BUDGET_TOO_SMALL,
    REWARD_BELOW_MIN;

    /** Mongolian message shown to the company (same strings as the TS map). */
    public String message(long minRewardPerViewer) {
        return switch (this) {
            case BUDGET_INVALID -> "Нийт төсвөө оруулна уу";
            case VIEWERS_INVALID -> "Үзэгчийн тоогоо оруулна уу";
            case REWARD_INVALID -> "Нэг үзэгчид олгох урамшууллаа оруулна уу";
            case BUDGET_TOO_SMALL ->
                    "Төсөв хэт бага байна — үзэгчийн тоог багасгах эсвэл төсвөө нэмнэ үү";
            case REWARD_BELOW_MIN ->
                    "Нэг үзэгчид олгох урамшуулал хамгийн багадаа " + minRewardPerViewer + " ₮ байх ёстой";
        };
    }
}
