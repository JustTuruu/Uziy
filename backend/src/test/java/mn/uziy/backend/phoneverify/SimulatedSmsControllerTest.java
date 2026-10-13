package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import mn.uziy.backend.common.NotFoundException;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class SimulatedSmsControllerTest {

    private final SimulatedPhoneVerificationGateway gateway =
            new SimulatedPhoneVerificationGateway(Clock.systemUTC());
    private final SimulatedSmsController controller = new SimulatedSmsController(gateway);

    @Test
    void marksTheSessionsSmsAsArrived() {
        String id = gateway.start("88112233", "482916").sessionId();

        assertThat(controller.receive(id).getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        assertThat(gateway.status(id)).isEqualTo(PhoneVerificationStatus.VERIFIED);
    }

    @Test
    void anUnknownSessionIs404() {
        assertThatThrownBy(() -> controller.receive("nope"))
                .isInstanceOf(NotFoundException.class)
                .hasMessage(SimulatedSmsController.UNKNOWN_SESSION);
    }
}
