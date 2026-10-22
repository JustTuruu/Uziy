package mn.uziy.backend.consolelogin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.util.UUID;
import mn.uziy.backend.auth.Me;
import mn.uziy.backend.domain.Role;
import org.junit.jupiter.api.Test;

/** The controller is an adapter: it hands the second step and the User-Agent to {@link ConsoleLoginService}. */
class ConsoleLoginControllerTest {

    @Test
    void verifyReturnsTheServicesAnswer() {
        ConsoleLoginService service = mock(ConsoleLoginService.class);
        ConsoleLoginVerifyReq req = new ConsoleLoginVerifyReq("99001122", UUID.randomUUID());
        ConsoleLoginVerifiedRes res = new ConsoleLoginVerifiedRes("t",
                new Me(1L, "99001122", Role.COMPANY, null, null, null, 0.0, false, "MobiCom", null, null),
                "device", OffsetDateTime.parse("2026-11-21T04:00:00Z"));
        when(service.verify(req, "Chrome/141.0")).thenReturn(res);

        assertThat(new ConsoleLoginController(service).verify(req, "Chrome/141.0")).isSameAs(res);
    }
}
