package mn.uziy.backend.domain;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** Users, looked up by their unique 8-digit phone number. */
@Repository
public interface UserRepository extends JpaRepository<UserEntity, Long> {
    Optional<UserEntity> findByPhoneNumber(String phoneNumber);

    boolean existsByPhoneNumber(String phoneNumber);

    /** The account's current role, or empty when it no longer exists. */
    @Query("SELECT u.role FROM UserEntity u WHERE u.id = :id")
    Optional<Role> roleOf(@Param("id") long id);

    /**
     * Atomically takes {@code amount} from the balance, only if that much is there. Returns 1 when it
     * did, 0 when the balance was too small — so two parallel withdrawals can never spend the same money.
     */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE UserEntity u SET u.balance = u.balance - :amount WHERE u.id = :id AND u.balance >= :amount")
    int tryDeductBalance(@Param("id") long id, @Param("amount") double amount);

    /** Atomically adds {@code amount} to the balance (a reward, or a refunded payout reservation). */
    @Modifying(flushAutomatically = true)
    @Query("UPDATE UserEntity u SET u.balance = u.balance + :amount WHERE u.id = :id")
    int addBalance(@Param("id") long id, @Param("amount") double amount);

    /** The balance as the database holds it right now, bypassing any cached entity. */
    @Query("SELECT u.balance FROM UserEntity u WHERE u.id = :id")
    Optional<Double> currentBalance(@Param("id") long id);
}
