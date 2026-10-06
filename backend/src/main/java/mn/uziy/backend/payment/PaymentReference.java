package mn.uziy.backend.payment;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

/** Builds the invoice number shown to the company. */
public final class PaymentReference {

    private static final ZoneId ZONE = ZoneId.of("Asia/Ulaanbaatar");
    private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyyMMdd");

    private PaymentReference() {
    }

    /** Invoice number shown to the company: UZ-&lt;yyyyMMdd in Ulaanbaatar&gt;-&lt;campaignId&gt;. */
    public static String of(long campaignId, OffsetDateTime at) {
        return "UZ-" + at.atZoneSameInstant(ZONE).format(DATE) + "-" + campaignId;
    }
}
