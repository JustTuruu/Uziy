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

/** The controller is an adapter: it passes the signed-in admin to {@link CompanyAccountService}. */
class CompanyAccountControllerTest {

    private final CompanyAccountService service = mock(CompanyAccountService.class);
    private final CompanyAccountController controller = new CompanyAccountController(service);
    private final JwtPrincipal admin = new JwtPrincipal(1L, Role.ADMIN);
    private final CompanyAccountDto dto = new CompanyAccountDto(7L, "MobiCom", "88112233",
            OffsetDateTime.parse("2026-10-22T04:00:00Z"), 0);

    @Test
    void createAnswers201WithTheNewAccount() {
        CreateCompanyReq req = new CreateCompanyReq("MobiCom", "88112233", "temp-pass1");
        when(service.create(req, 1L)).thenReturn(dto);

        ResponseEntity<CompanyAccountDto> out = controller.create(req, admin);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(out.getBody()).isSameAs(dto);
    }

    @Test
    void listReturnsTheServicesList() {
        when(service.list(1L)).thenReturn(List.of(dto));

        assertThat(controller.list(admin)).containsExactly(dto);
    }
}
