package mn.uziy.backend.phoneverify;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class PhoneVerificationControllerTest {

    private final PhoneVerificationService service = mock(PhoneVerificationService.class);
    private final PhoneVerificationController controller = new PhoneVerificationController(service);
    private final UUID id = UUID.randomUUID();
    private final OffsetDateTime expires = OffsetDateTime.parse("2026-10-13T04:05:00Z");

    @Test
    void startAnswers201WithTheInstructions() {
        var started = new PhoneVerificationStartedRes(id, "88112233", "144773", "482916", "sms:144773?body=482916",
                "instruction", PhoneVerificationStatus.PENDING, expires);
        when(service.start("88112233", PhoneVerificationPurpose.REGISTER)).thenReturn(started);

        var res = controller.start(new StartPhoneVerificationReq("88112233", null));

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(res.getBody()).isEqualTo(started);
    }

    @Test
    void aResetStartPassesItsPurposeThrough() {
        var started = new PhoneVerificationStartedRes(id, "88112233", "144773", "482916", "sms:144773?body=482916",
                "instruction", PhoneVerificationStatus.PENDING, expires);
        when(service.start("88112233", PhoneVerificationPurpose.PASSWORD_RESET)).thenReturn(started);

        var res = controller.start(
                new StartPhoneVerificationReq("88112233", PhoneVerificationPurpose.PASSWORD_RESET));

        assertThat(res.getBody()).isEqualTo(started);
    }

    @Test
    void checkReturnsTheState() {
        var state = new PhoneVerificationStateRes(id, PhoneVerificationStatus.VERIFIED, expires);
        when(service.check(id)).thenReturn(state);

        assertThat(controller.check(id)).isEqualTo(state);
    }
}
