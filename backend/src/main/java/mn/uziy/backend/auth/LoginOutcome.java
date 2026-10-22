package mn.uziy.backend.auth;

import mn.uziy.backend.consolelogin.ConsoleLoginChallenge;

/**
 * What a correct password leads to: viewers are signed in at once, and so are admins and companies on a browser they
 * already proved their phone from; otherwise the phone must still be proved ({@code POST /auth/login/verify}).
 */
public sealed interface LoginOutcome permits LoginOutcome.SignedIn, LoginOutcome.SecondStepRequired {

    record SignedIn(AuthResponse response) implements LoginOutcome {
    }

    record SecondStepRequired(ConsoleLoginChallenge challenge) implements LoginOutcome {
    }
}
