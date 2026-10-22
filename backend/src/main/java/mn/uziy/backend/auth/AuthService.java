package mn.uziy.backend.auth;

/**
 * Authentication and viewer self-registration. Company accounts are made by an admin ({@code POST /admin/companies}),
 * never by the company itself.
 */
public interface AuthService {
    LoginOutcome login(LoginReq req);

    AuthResponse registerViewer(RegisterViewerReq req);
}
