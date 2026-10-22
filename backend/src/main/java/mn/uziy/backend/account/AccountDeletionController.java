package mn.uziy.backend.account;

import jakarta.validation.Valid;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter: a viewer deletes their own account ({@code DELETE /viewer/me {password}} → 204). */
@RestController
@RequestMapping("/viewer/me")
@PreAuthorize("hasRole('VIEWER')")
public class AccountDeletionController {

    private final AccountDeletionService deletion;

    public AccountDeletionController(AccountDeletionService deletion) {
        this.deletion = deletion;
    }

    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@Valid @RequestBody DeleteAccountReq body, @Auth JwtPrincipal principal) {
        deletion.deleteOwnAccount(principal.userId(), body.password());
    }
}
