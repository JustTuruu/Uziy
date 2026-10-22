package mn.uziy.backend.trusteddevice;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/** The controller is an adapter: it hands the request to the service and answers 204. */
class TrustedDeviceAdminControllerTest {

    @Test
    void forgetAnswers204AndNamesTheAdmin() {
        TrustedDeviceAdminService service = mock(TrustedDeviceAdminService.class);

        var res = new TrustedDeviceAdminController(service).forget(12L, new JwtPrincipal(1L, Role.ADMIN));

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(service).forgetAll(12L, 1L);
    }
}
