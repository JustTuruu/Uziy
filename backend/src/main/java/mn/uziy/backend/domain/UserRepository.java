package mn.uziy.backend.domain;

import java.time.OffsetDateTime;
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
    @Query("SELECT new mn.uziy.backend.domain.AccountState(u.role, u.credentialsChangedAt) "
            + "FROM UserEntity u WHERE u.id = :id")
    Optional<AccountState> accountState(@Param("id") long id);

    /**
     * Sets a new password for the account of {@code phone} with {@code role}, in one UPDATE that touches nothing
     * else. Loading the entity and saving it back instead could write an old balance over a payout made in
     * between (audit 2026-10-22). Returns 0 when there is no such account.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE UserEntity u SET u.passwordHash = :hash, u.credentialsChangedAt = :at "
            + "WHERE u.phoneNumber = :phone AND u.role = :role")
    int trySetPassword(@Param("phone") String phone, @Param("role") Role role, @Param("hash") String hash,
                       @Param("at") OffsetDateTime at);

    /** Marks the account verified without loading and saving it back (same reason as {@link #trySetPassword}). */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE UserEntity u SET u.verified = true WHERE u.id = :id")
    int markVerified(@Param("id") long id);

    /**
     * Atomically takes {@code amount} from the balance, only if that much is there. Returns 1 when it
     * did, 0 when the balance was too small — so two parallel withdrawals can never spend the same money.
     */
    /**
     * Gives a name to an account made before registration asked for one, once: only while BOTH names are still
     * empty and only for {@code role}. One conditional UPDATE, so two racing requests cannot both write. 0 = not
     * changed (the names were already set, or the user is not of that role).
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("UPDATE UserEntity u SET u.lastName = :lastName, u.firstName = :firstName "
            + "WHERE u.id = :id AND u.role = :role AND u.lastName IS NULL AND u.firstName IS NULL")
    int trySetNameOnce(@Param("id") long id, @Param("role") Role role, @Param("lastName") String lastName,
                       @Param("firstName") String firstName);

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
