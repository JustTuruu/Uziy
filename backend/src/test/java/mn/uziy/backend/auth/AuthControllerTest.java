package mn.uziy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import mn.uziy.backend.adminlogin.AdminLoginChallenge;
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
        return new AuthResponse("t", new Me(1L, "88112233", role, null, null, null, 0.0, false, null, null, null));
    }

    @Test
    void aSignedInLoginAnswers200WithTheServiceResponse() {
        AuthResponse res = response(Role.VIEWER);
        LoginReq req = new LoginReq("88112233", "password");
        when(service.login(req)).thenReturn(new LoginOutcome.SignedIn(res));

        ResponseEntity<Object> out = controller.login(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(out.getBody()).isSameAs(res);
    }

    @Test
    void anAdminSecondStepAnswers202WithTheChallengeAndNoToken() {
        LoginReq req = new LoginReq("88112233", "password");
        AdminLoginChallenge challenge = new AdminLoginChallenge(new AdminLoginChallenge.TwoStep(
                java.util.UUID.randomUUID(), "•••• 2233", "144773", "123456", "sms:144773", "SMS",
                java.time.OffsetDateTime.parse("2026-10-22T04:05:00Z")));
        when(service.login(req)).thenReturn(new LoginOutcome.SecondStepRequired(challenge));

        ResponseEntity<Object> out = controller.login(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.ACCEPTED);
        assertThat(out.getBody()).isSameAs(challenge);
    }

    @Test
    void registerViewerAnswers201WithTheServiceResponse() {
        RegisterViewerReq req = new RegisterViewerReq("88112233", "password1", "Бат", "Болд", Gender.MALE,
                LocalDate.of(2000, 1, 1), "Улаанбаатар", java.util.UUID.randomUUID());
        when(service.registerViewer(req)).thenReturn(response(Role.VIEWER));

        ResponseEntity<AuthResponse> out = controller.registerViewer(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(out.getBody().user().role()).isEqualTo(Role.VIEWER);
    }
}
