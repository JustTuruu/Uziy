package mn.uziy.backend.handoff;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** The controller is an adapter: it passes the signed-in admin, or the code, to {@link SessionHandoffService}. */
class SessionHandoffControllerTest {

    private final SessionHandoffService service = mock(SessionHandoffService.class);
    private final SessionHandoffController controller = new SessionHandoffController(service);

    @Test
    void createAnswers201WithTheCode() {
        HandoffCode code = new HandoffCode("abc", OffsetDateTime.parse("2026-10-22T04:01:00Z"));
        when(service.create(1L)).thenReturn(code);

        var out = controller.create(new JwtPrincipal(1L, Role.ADMIN));

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(out.getBody()).isSameAs(code);
    }

    @Test
    void redeemReturnsTheSession() {
        AuthResponse session = new AuthResponse("jwt", null);
        when(service.redeem("abc")).thenReturn(session);

        assertThat(controller.redeem(new RedeemHandoffReq("abc"))).isSameAs(session);
    }
}
