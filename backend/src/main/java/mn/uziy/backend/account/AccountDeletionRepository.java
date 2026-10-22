package mn.uziy.backend.account;

import java.time.OffsetDateTime;
import mn.uziy.backend.domain.UserEntity;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

/**
 * The statements that delete a viewer's personal data. Each one is a single conditional SQL statement — the user row
 * is never loaded, changed and saved back (a payout running in between would get its balance overwritten).
 */
public interface AccountDeletionRepository extends Repository<UserEntity, Long> {

    /**
     * Strips the viewer row of everything personal, in one UPDATE, only while it is still a VIEWER with the
     * password hash the caller just checked (a password changed in between, or a second delete, changes nothing).
     * The row itself stays: view history and survey answers point at it, and the counts companies paid for must
     * not shrink. Returns 1 when the row was anonymised, 0 otherwise.
     */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query(value = """
            UPDATE users SET phone_number = :tombstone, password_hash = :unusableHash,
                   gender = NULL, birth_date = NULL, city = NULL, district = NULL,
                   last_name = NULL, first_name = NULL, balance = 0, is_verified = FALSE,
                   stats_consent = NULL, stats_consent_at = NULL, stats_consent_version = NULL,
                   credentials_changed_at = :tokensInvalidBefore
            WHERE id = :id AND role = 'VIEWER' AND password_hash = :expectedHash""", nativeQuery = true)
    int tryAnonymiseViewer(@Param("id") long id, @Param("expectedHash") String expectedHash,
                           @Param("tombstone") String tombstone, @Param("unusableHash") String unusableHash,
                           @Param("tokensInvalidBefore") OffsetDateTime tokensInvalidBefore);

    /** Forgets every push token of the user: nothing may be sent to that phone any more. */
    @Modifying(flushAutomatically = true)
    @Query(value = "DELETE FROM device_tokens WHERE user_id = :id", nativeQuery = true)
    int deleteDeviceTokens(@Param("id") long id);

    /** Forgets the phone checks made for {@code phone} (they hold the number, and would rate-limit a new sign-up). */
    @Modifying(flushAutomatically = true)
    @Query(value = "DELETE FROM phone_verifications WHERE phone_number = :phone", nativeQuery = true)
    int deletePhoneVerifications(@Param("phone") String phone);

    /**
     * Deletes the user's free-text survey answers: they can contain anything the person typed about themselves.
     * Choice and rating answers stay as anonymous rows, so companies' results do not change.
     */
    @Modifying(flushAutomatically = true)
    @Query(value = """
            DELETE FROM survey_responses sr
            USING view_history vh, survey_questions q
            WHERE sr.view_id = vh.id AND vh.user_id = :id AND sr.question_id = q.id AND q.q_type = 'TEXT'""",
            nativeQuery = true)
    int deleteFreeTextAnswers(@Param("id") long id);

    /**
     * Keeps the user's decided payout requests for the books (amount, bank, status, dates) but removes the account
     * holder's name and all but the last four digits of the account number.
     */
    @Modifying(flushAutomatically = true)
    @Query(value = """
            UPDATE payout_requests
            SET account_name = '', account_number = :mask || RIGHT(account_number, :keptDigits)
            WHERE user_id = :id""", nativeQuery = true)
    int maskPayoutAccounts(@Param("id") long id, @Param("mask") String mask, @Param("keptDigits") int keptDigits);
}
