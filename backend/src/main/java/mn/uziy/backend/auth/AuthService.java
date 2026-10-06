package mn.uziy.backend.auth;

/** Authentication and self-registration use cases. */
public interface AuthService {
    AuthResponse login(LoginReq req);

    AuthResponse registerViewer(RegisterViewerReq req);

    AuthResponse registerCompany(RegisterCompanyReq req);
}
