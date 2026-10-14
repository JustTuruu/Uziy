package mn.uziy.backend.privacy;

/** A viewer's answer to "may your answers be used in anonymous statistics?". */
public enum StatisticsConsentStatus {
    /** Never asked (or asked about an older wording): treated as no. */
    UNASKED,
    GRANTED,
    DECLINED
}
