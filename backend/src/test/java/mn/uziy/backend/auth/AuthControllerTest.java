package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import mn.uziy.backend.domain.Gender;
import mn.uziy.backend.domain.Role;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** The controller is an adapter: it delegates to {@link AuthService} and sets the HTTP status. */
class AuthControllerTest {

    private final AuthService service = mock(AuthService.class);
    private final AuthController controller = new AuthController(service);

    private AuthResponse response(Role role) {
        return new AuthResponse("t", new Me(1L, "88112233", role, null, null, null, 0.0, false, null));
    }

    @Test
    void loginDelegatesToTheServiceAndReturnsItsResponse() {
        AuthResponse res = response(Role.VIEWER);
        LoginReq req = new LoginReq("88112233", "password");
        when(service.login(req)).thenReturn(res);
        assertThat(controller.login(req)).isSameAs(res);
    }

    @Test
    void registerViewerAnswers201WithTheServiceResponse() {
        RegisterViewerReq req = new RegisterViewerReq("88112233", "password1", Gender.MALE,
                LocalDate.of(2000, 1, 1), "Улаанбаатар");
        when(service.registerViewer(req)).thenReturn(response(Role.VIEWER));

        ResponseEntity<AuthResponse> out = controller.registerViewer(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(out.getBody().user().role()).isEqualTo(Role.VIEWER);
    }

    @Test
    void registerCompanyAnswers201WithTheServiceResponse() {
        RegisterCompanyReq req = new RegisterCompanyReq("88112233", "password1", "MobiCom");
        when(service.registerCompany(req)).thenReturn(response(Role.COMPANY));

        ResponseEntity<AuthResponse> out = controller.registerCompany(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        verify(service, times(1)).registerCompany(req);
    }
}
