package mn.uziy.backend.rejoin;

import mn.uziy.backend.auth.UserRegistered;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Pattern: Observer — a new viewer account inherits the campaigns its number completed under deleted accounts.
 * Events are delivered synchronously, so this runs inside the registration's transaction.
 */
@Component
public class CompletionCarryOverOnRegistration {

    private final UserRepository users;
    private final CompletionCarryOver carryOver;

    public CompletionCarryOverOnRegistration(UserRepository users, CompletionCarryOver carryOver) {
        this.users = users;
        this.carryOver = carryOver;
    }

    @EventListener
    public void onUserRegistered(UserRegistered event) {
        if (event.role() != Role.VIEWER) {
            return;
        }
        users.findById(event.userId())
                .ifPresent(viewer -> carryOver.carryOverToNewAccount(viewer.getId(), viewer.getPhoneNumber()));
    }
}
