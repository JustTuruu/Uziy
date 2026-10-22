package mn.uziy.backend.account;

/** A viewer deletes their own account from the app (App Store 5.1.1(v), Google Play account-deletion policy). */
public interface AccountDeletionService {

    /**
     * Deletes the account of {@code viewerId} after checking {@code password}. Any balance left is forfeited.
     *
     * @throws mn.uziy.backend.common.BadRequestException when the password is wrong
     * @throws mn.uziy.backend.common.ConflictException while a payout request is still waiting for a decision
     */
    void deleteOwnAccount(long viewerId, String password);
}
