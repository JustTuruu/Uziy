package mn.uziy.backend.passwordreset;

import java.time.Clock;
import java.time.OffsetDateTime;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
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
    private final Clock clock;
    private final DomainEventPublisher events;

    public PasswordResetServiceImpl(VerifiedPhoneClaim verifiedPhones, UserRepository users,
                                    PasswordEncoder encoder, LoginAttemptLimiter loginLimiter, Clock clock,
                                    DomainEventPublisher events) {
        this.verifiedPhones = verifiedPhones;
        this.users = users;
        this.encoder = encoder;
        this.loginLimiter = loginLimiter;
        this.clock = clock;
        this.events = events;
    }

    /**
     * One transaction: spend the phone check, then set the password with a single UPDATE. The account is never
     * loaded and saved back — that wrote a stale balance over a payout made while the provider was being asked
     * (audit 2026-10-22). No viewer with that phone → the check is given back (rollback).
     */
    @Override
    @Transactional
    public void reset(ResetPasswordReq req) {
        verifiedPhones.claim(req.verificationId(), req.phoneNumber(), PhoneVerificationPurpose.PASSWORD_RESET);
        int updated = users.trySetPassword(req.phoneNumber(), Role.VIEWER, encoder.encode(req.newPassword()),
                OffsetDateTime.now(clock));
        if (updated == 0) {
            throw new BadRequestException(VerifiedPhoneClaim.NOT_VERIFIED);
        }
        // They just proved the phone: a lock from earlier wrong guesses must not keep them out.
        loginLimiter.recordSuccess(req.phoneNumber());
        // Observers forget what the old password unlocked (e.g. remembered browsers), in this transaction.
        users.findIdByPhoneNumber(req.phoneNumber()).ifPresent(id -> events.publish(new PasswordReset(id)));
    }
}
