package mn.uziy.backend.adminlogin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.UUID;
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.domain.Role;
import org.junit.jupiter.api.Test;

/** The controller is an adapter: it hands the second step to {@link AdminLoginService}. */
class AdminLoginControllerTest {

    @Test
    void verifyReturnsTheServicesSignedInResponse() {
        AdminLoginService service = mock(AdminLoginService.class);
        AdminLoginVerifyReq req = new AdminLoginVerifyReq("99001122", UUID.randomUUID());
        AuthResponse res = new AuthResponse("t",
                new Me(1L, "99001122", Role.ADMIN, null, null, null, 0.0, false, null, null, null));
        when(service.verify(req)).thenReturn(res);

        assertThat(new AdminLoginController(service).verify(req)).isSameAs(res);
    }
}
