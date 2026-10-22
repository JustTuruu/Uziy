package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.util.List;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/** The controller is an adapter: it passes the signed-in admin to {@link AdminAccountService}. */
class AdminAccountControllerTest {

    private final AdminAccountService service = mock(AdminAccountService.class);
    private final AdminAccountController controller = new AdminAccountController(service);
    private final JwtPrincipal admin = new JwtPrincipal(1L, Role.ADMIN);
    private final AdminAccountDto dto = new AdminAccountDto(7L, "88112233",
            OffsetDateTime.parse("2026-10-22T04:00:00Z"));

    @Test
    void createAnswers201WithTheNewAccount() {
        CreateAdminReq req = new CreateAdminReq("88112233", "temp-pass1");
        when(service.create(req, 1L)).thenReturn(dto);

        ResponseEntity<AdminAccountDto> out = controller.create(req, admin);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(out.getBody()).isSameAs(dto);
    }

    @Test
    void listReturnsTheServicesList() {
        when(service.list(1L)).thenReturn(List.of(dto));

        assertThat(controller.list(admin)).containsExactly(dto);
    }
}
