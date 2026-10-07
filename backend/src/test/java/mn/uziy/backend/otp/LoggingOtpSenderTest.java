package mn.uziy.backend.otp;

import org.junit.jupiter.api.Test;

class LoggingOtpSenderTest {

    @Test
    void sendingNeverThrows() {
        new LoggingOtpSender().send("88112233", "123456", OtpPurpose.REGISTER);
    }
}
