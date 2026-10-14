package mn.uziy.backend.privacy;

/** A viewer's own consent to their answers being used in anonymous statistics. */
public interface StatisticsConsentService {

    /** The wording the app shows now; a consent given to another wording counts as {@link StatisticsConsentStatus#UNASKED}. */
    String CURRENT_VERSION = "2026-10-14";

    StatisticsConsentDto current(long viewerId);

    /** Records yes or no for the current wording; takes effect for every statistic from now on. */
    StatisticsConsentDto decide(long viewerId, boolean granted);
}
