package mn.uziy.backend.consolelogin;

import jakarta.validation.Valid;
import org.jspecify.annotations.Nullable;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * HTTP adapter for the console login's second step (open: /auth/** needs no token).
 *
 * <p>Flow: {@code POST /auth/login} with an admin's or a company's correct password and no recognised
 * {@code deviceToken} answers <b>202 Accepted</b> with {@link ConsoleLoginChallenge} ({@code {"twoStep": {...}}}, no
 * token). The person texts {@code smsText} from the account's phone to {@code shortcode}; the panel polls
 * {@code GET /auth/phone-verifications/{verificationId}} and, once it says {@code VERIFIED}, calls
 * {@code POST /auth/login/verify} here: 200 with {@link ConsoleLoginVerifiedRes}. A check that is not confirmed,
 * already used, too old, or opened for another phone, role or purpose answers 400.
 */
@RestController
@RequestMapping("/auth/login")
public class ConsoleLoginController {

    private final ConsoleLoginService consoleLogin;

    public ConsoleLoginController(ConsoleLoginService consoleLogin) {
        this.consoleLogin = consoleLogin;
    }

    @PostMapping("/verify")
    public ConsoleLoginVerifiedRes verify(@Valid @RequestBody ConsoleLoginVerifyReq body,
                                          @RequestHeader(name = HttpHeaders.USER_AGENT, required = false)
                                          @Nullable String userAgent) {
        return consoleLogin.verify(body, userAgent);
    }
}
