package mn.uziy.backend.auth;

import mn.uziy.backend.adminlogin.AdminLoginChallenge;

/**
 * What a correct password leads to: viewers and companies are signed in at once; an admin must still prove the
 * account's phone ({@code POST /auth/admin/login/verify}).
 */
public sealed interface LoginOutcome permits LoginOutcome.SignedIn, LoginOutcome.SecondStepRequired {

    record SignedIn(AuthResponse response) implements LoginOutcome {
    }

    record SecondStepRequired(AdminLoginChallenge challenge) implements LoginOutcome {
    }
}
