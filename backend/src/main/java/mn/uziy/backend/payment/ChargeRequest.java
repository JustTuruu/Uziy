package mn.uziy.backend.payment;

import java.time.OffsetDateTime;

/**
 * @param amount whole ₮
 */
public record ChargeRequest(long campaignId, long companyId, double amount, OffsetDateTime at) {
}
