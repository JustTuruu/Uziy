package mn.uziy.backend.payout;

import mn.uziy.backend.domain.PayoutEntity;
import org.springframework.stereotype.Component;

/** Pattern: Mapper — turns payout entities into {@link PayoutDto}s. */
@Component
public class PayoutMapper {

    public PayoutDto toDto(PayoutEntity p, String phone) {
        return new PayoutDto(
                p.getId(), p.getUserId(), phone,
                p.getAmount(), p.getBank(), p.getAccountNumber(),
                p.getAccountName(), p.getNationalId(),
                p.getStatus(), p.isFirstPayout(),
                p.getRequestedAt(), p.getDecidedAt(),
                p.getRejectReason());
    }
}
