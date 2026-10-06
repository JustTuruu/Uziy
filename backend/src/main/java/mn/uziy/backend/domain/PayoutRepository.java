package mn.uziy.backend.domain;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/** Payout requests. */
@Repository
public interface PayoutRepository extends JpaRepository<PayoutEntity, Long> {
    List<PayoutEntity> findAllByStatusOrderByRequestedAtAsc(PayoutStatus status);

    List<PayoutEntity> findAllByUserIdOrderByRequestedAtDesc(long userId);

    boolean existsByUserIdAndStatus(long userId, PayoutStatus status);

    /**
     * Decided payouts (APPROVED or REJECTED) newest-first. Used by the
     * admin history table so the super admin sees what was already
     * processed, not just what's still pending.
     */
    List<PayoutEntity> findAllByStatusInOrderByDecidedAtDesc(Collection<PayoutStatus> statuses);
}
