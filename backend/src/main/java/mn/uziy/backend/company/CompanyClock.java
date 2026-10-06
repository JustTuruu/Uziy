package mn.uziy.backend.company;

import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;

/** Time source shared by the company services (so neither depends on the other's class). */
final class CompanyClock {

    private CompanyClock() {
    }

    /** Postgres keeps microseconds — truncate so the response matches what is stored. */
    static OffsetDateTime now() {
        return OffsetDateTime.now().truncatedTo(ChronoUnit.MICROS);
    }
}
