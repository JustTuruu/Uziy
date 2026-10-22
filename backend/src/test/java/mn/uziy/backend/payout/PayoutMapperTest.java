package mn.uziy.backend.payout;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutStatus;
import org.junit.jupiter.api.Test;

class PayoutMapperTest {

    @Test
    void mapsEveryFieldAndTheSuppliedPhone() {
        OffsetDateTime decided = OffsetDateTime.parse("2026-10-06T00:00:00Z");
        PayoutEntity p = new PayoutEntity();
        p.setId(7L);
        p.setUserId(42L);
        p.setAmount(500.0);
        p.setBank("Khan");
        p.setAccountNumber("123");
        p.setAccountName("Name");
        p.setStatus(PayoutStatus.REJECTED);
        p.setFirstPayout(true);
        p.setDecidedAt(decided);
        p.setRejectReason("bad");

        PayoutDto dto = new PayoutMapper().toDto(p, "77000001");

        assertThat(dto).isEqualTo(new PayoutDto(7L, 42L, "77000001", 500.0, "Khan", "123", "Name",
                PayoutStatus.REJECTED, true, p.getRequestedAt(), decided, "bad"));
    }

    private static PayoutEntity withAccount(PayoutStatus status) {
        PayoutEntity p = new PayoutEntity();
        p.setId(8L);
        p.setUserId(42L);
        p.setAmount(5000.0);
        p.setBank("Khan");
        p.setAccountNumber("5001234567");
        p.setAccountName("Name");
        p.setStatus(status);
        return p;
    }

    @Test
    void theAdminSeesAPendingRequestsWholeAccountNumberToPayIt() {
        assertThat(new PayoutMapper().toAdminDto(withAccount(PayoutStatus.PENDING), "77000001").accountNumber())
                .isEqualTo("5001234567");
    }

    @Test
    void aDecidedRequestShowsOnlyTheLastFourDigitsToTheAdmin() {
        PayoutMapper mapper = new PayoutMapper();
        assertThat(mapper.toAdminDto(withAccount(PayoutStatus.APPROVED), "77000001").accountNumber())
                .isEqualTo("•••• 4567");
        assertThat(mapper.toAdminDto(withAccount(PayoutStatus.REJECTED), "77000001").accountNumber())
                .isEqualTo("•••• 4567");
    }

    @Test
    void theViewerAlwaysSeesTheirOwnWholeAccountNumber() {
        assertThat(new PayoutMapper().toDto(withAccount(PayoutStatus.APPROVED), "77000001").accountNumber())
                .isEqualTo("5001234567");
    }
}
