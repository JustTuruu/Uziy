package mn.uziy.backend.domain;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
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

    /**
     * Claims a PENDING payout for a decision: flips it out of PENDING in one statement, so two admins
     * deciding at once cannot both win (the second matches 0 rows). Returns 1 for the winner.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("UPDATE PayoutEntity p SET p.status = :decision WHERE p.id = :id AND p.status = mn.uziy.backend.domain.PayoutStatus.PENDING")
    int tryClaim(@Param("id") long id, @Param("decision") PayoutStatus decision);
}
