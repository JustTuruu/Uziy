package mn.uziy.backend.otp;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class OtpControllerTest {

    private final OtpRequestService requests = mock(OtpRequestService.class);
    private final PasswordResetService reset = mock(PasswordResetService.class);
    private final OtpController controller = new OtpController(requests, reset);

    @Test
    void requestAnswers204AndHandsPhoneAndPurposeToTheService() {
        var out = controller.request(new OtpRequestReq("88112233", OtpPurpose.REGISTER));

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(requests).requestCode("88112233", OtpPurpose.REGISTER);
    }

    @Test
    void resetAnswers204AndDelegates() {
        ResetPasswordReq req = new ResetPasswordReq("88112233", "123456", "new-password");

        var out = controller.reset(req);

        assertThat(out.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        verify(reset).reset(req);
    }
}
