package mn.uziy.backend.otp;

import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class OtpRequestServiceImpl implements OtpRequestService {

    private final OtpService otp;
    private final UserRepository users;

    public OtpRequestServiceImpl(OtpService otp, UserRepository users) {
        this.otp = otp;
        this.users = users;
    }

    @Override
    public void requestCode(String phoneNumber, OtpPurpose purpose) {
        boolean viewerExists = users.findByPhoneNumber(phoneNumber)
                .filter(u -> u.getRole() == Role.VIEWER)
                .isPresent();
        if (viewerExists) {
            otp.issue(phoneNumber, purpose);
        }
    }
}
