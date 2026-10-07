package mn.uziy.backend.otp;

import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PasswordResetServiceImpl implements PasswordResetService {

    private final OtpService otp;
    private final UserRepository users;
    private final PasswordEncoder encoder;

    public PasswordResetServiceImpl(OtpService otp, UserRepository users, PasswordEncoder encoder) {
        this.otp = otp;
        this.users = users;
        this.encoder = encoder;
    }

    @Override
    @Transactional
    public void reset(ResetPasswordReq req) {
        otp.verifyAndConsume(req.phoneNumber(), OtpPurpose.PASSWORD_RESET, req.code());
        UserEntity user = users.findByPhoneNumber(req.phoneNumber())
                .filter(u -> u.getRole() == Role.VIEWER)
                .orElseThrow(() -> new BadRequestException(OtpService.INVALID_CODE));
        user.setPasswordHash(encoder.encode(req.newPassword()));
        users.save(user);
    }
}
