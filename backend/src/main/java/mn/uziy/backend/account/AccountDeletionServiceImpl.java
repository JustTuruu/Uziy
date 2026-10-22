package mn.uziy.backend.account;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Deletes a viewer's account at their own request. What "deleted" means here (decided 2026-10-22; owner / lawyer to
 * review):
 * <ul>
 *   <li><b>Personal data is erased</b>: phone number (replaced by a unique tombstone, so the number can register
 *       again), овог/нэр, gender, birth date, city, district, statistics consent. The password hash is replaced by a
 *       value no password matches, and {@code credentials_changed_at} moves past "now", so every token already
 *       issued is refused at once (JWTs keep whole seconds, hence the extra second; no new token can ever be
 *       issued for the row).</li>
 *   <li><b>The balance is forfeited</b> (set to 0). The app warns about it before the viewer confirms.</li>
 *   <li><b>Refused (409) while a payout request is PENDING</b>: money is about to be sent to the viewer's bank
 *       account, and the reviewer must still be able to check that account against the profile.</li>
 *   <li><b>Push tokens and phone checks are deleted</b>; <b>free-text answers are deleted</b> (they can hold
 *       anything personal); choice/rating answers and the view history stay, now tied only to an empty row, so the
 *       results companies paid for do not change and nothing in them leads back to the person.</li>
 *   <li><b>Decided payouts stay for the books</b> (amount, bank, status, dates) without the holder's name and with
 *       only the last {@value #KEPT_ACCOUNT_DIGITS} digits of the account number.</li>
 * </ul>
 * One transaction. The user row is never loaded-modified-saved: the anonymising UPDATE is conditional on the
 * password hash that was checked, and it runs BEFORE the pending-payout check — it locks the row, so a payout
 * request racing with the deletion either committed first (then the check sees it and everything rolls back) or
 * waits and then finds a zero balance.
 */
@Service
public class AccountDeletionServiceImpl implements AccountDeletionService {

    /** Marks a deleted row's phone column; never 8 digits, so it can neither log in nor clash with a real number. */
    static final String TOMBSTONE_PREFIX = "DEL-";
    /** Not a BCrypt hash: no password can ever match it. */
    static final String UNUSABLE_PASSWORD_HASH = "!deleted";
    static final String ACCOUNT_NUMBER_MASK = "••••";
    static final int KEPT_ACCOUNT_DIGITS = 4;
    /** A token issued in the same second as the deletion must die too (JWT times are whole seconds). */
    private static final long TOKEN_CUTOFF_SECONDS = 1;

    private final UserRepository users;
    private final PayoutRepository payouts;
    private final AccountDeletionRepository deletion;
    private final PasswordEncoder encoder;
    private final DomainEventPublisher events;
    private final Clock clock;

    public AccountDeletionServiceImpl(UserRepository users, PayoutRepository payouts,
                                      AccountDeletionRepository deletion, PasswordEncoder encoder,
                                      DomainEventPublisher events, Clock clock) {
        this.users = users;
        this.payouts = payouts;
        this.deletion = deletion;
        this.encoder = encoder;
        this.events = events;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void deleteOwnAccount(long viewerId, String password) {
        UserEntity viewer = users.findById(viewerId)
                .filter(u -> u.getRole() == Role.VIEWER)
                .orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
        String checkedHash = viewer.getPasswordHash();
        if (!encoder.matches(password, checkedHash)) {
            throw new BadRequestException(AccountDeletionMessages.WRONG_PASSWORD);
        }
        String phone = viewer.getPhoneNumber();

        int anonymised = deletion.tryAnonymiseViewer(viewerId, checkedHash, tombstonePhone(viewerId),
                UNUSABLE_PASSWORD_HASH, tokenCutoff());
        if (anonymised == 0) {
            throw new ConflictException(AccountDeletionMessages.NOT_DELETED);
        }
        if (payouts.existsByUserIdAndStatus(viewerId, PayoutStatus.PENDING)) {
            throw new ConflictException(AccountDeletionMessages.PAYOUT_PENDING);
        }
        deletion.deleteDeviceTokens(viewerId);
        deletion.deletePhoneVerifications(phone);
        deletion.deleteFreeTextAnswers(viewerId);
        deletion.maskPayoutAccounts(viewerId, ACCOUNT_NUMBER_MASK, KEPT_ACCOUNT_DIGITS);
        events.publish(new ViewerDeleted(viewerId));
    }

    /** Unique per row (ids are) and at most 15 characters, the column's width. */
    static String tombstonePhone(long viewerId) {
        return TOMBSTONE_PREFIX + viewerId;
    }

    private OffsetDateTime tokenCutoff() {
        return OffsetDateTime.now(clock).truncatedTo(ChronoUnit.SECONDS).plusSeconds(TOKEN_CUTOFF_SECONDS);
    }
}
