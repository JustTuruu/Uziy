package mn.uziy.backend.passwordreset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class PasswordResetControllerTest {

    private final PasswordResetService service = mock(PasswordResetService.class);
    private final PasswordResetController controller = new PasswordResetController(service);

    @Test
    void aResetAnswers204() {
        var req = new ResetPasswordReq("88112233", UUID.randomUUID(), "newpass1");

        var res = controller.reset(req);

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(service).reset(req);
    }
}
