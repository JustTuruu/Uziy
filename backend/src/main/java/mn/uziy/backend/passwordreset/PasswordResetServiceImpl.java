package mn.uziy.backend.passwordreset;

import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PasswordResetServiceImpl implements PasswordResetService {

    private final VerifiedPhoneClaim verifiedPhones;
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final LoginAttemptLimiter loginLimiter;

    public PasswordResetServiceImpl(VerifiedPhoneClaim verifiedPhones, UserRepository users,
                                    PasswordEncoder encoder, LoginAttemptLimiter loginLimiter) {
        this.verifiedPhones = verifiedPhones;
        this.users = users;
        this.encoder = encoder;
        this.loginLimiter = loginLimiter;
    }

    @Override
    @Transactional
    public void reset(ResetPasswordReq req) {
        UserEntity viewer = users.findByPhoneNumber(req.phoneNumber())
                .filter(u -> u.getRole() == Role.VIEWER)
                .orElseThrow(() -> new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED));
        verifiedPhones.claim(req.verificationId(), req.phoneNumber(), PhoneVerificationPurpose.PASSWORD_RESET);
        viewer.setPasswordHash(encoder.encode(req.newPassword()));
        users.save(viewer);
        // They just proved the phone: a lock from earlier wrong guesses must not keep them out.
        loginLimiter.recordSuccess(req.phoneNumber());
    }
}
