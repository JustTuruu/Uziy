package mn.uziy.backend.payout;

import mn.uziy.backend.common.Masking;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — turns payout entities into {@link PayoutDto}s. */
@Component
public class PayoutMapper {

    /** The viewer's own requests: their own account number in full. */
    public PayoutDto toDto(PayoutEntity p, String phone) {
        return build(p, phone, p.getAccountNumber());
    }

    /**
     * The admin's view: the full account number only while the request is PENDING (it is needed to send the money);
     * once decided it is masked to {@code •••• 1234}, so the history is not a list of everybody's bank accounts.
     */
    public PayoutDto toAdminDto(PayoutEntity p, String phone) {
        String account = p.getStatus() == PayoutStatus.PENDING
                ? p.getAccountNumber()
                : Masking.lastFour(p.getAccountNumber());
        return build(p, phone, account);
    }

    private static PayoutDto build(PayoutEntity p, String phone, String accountNumber) {
        return new PayoutDto(
                p.getId(), p.getUserId(), phone,
                p.getAmount(), p.getBank(), accountNumber,
                p.getAccountName(),
                p.getStatus(), p.isFirstPayout(),
                p.getRequestedAt(), p.getDecidedAt(),
                p.getRejectReason());
    }
}
