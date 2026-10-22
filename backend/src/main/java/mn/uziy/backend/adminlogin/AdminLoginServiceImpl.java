package mn.uziy.backend.adminlogin;

import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.AdminPhoneCheck;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * An admin's password alone is not enough (owner, 2026-10-22): the account's phone must also be proved, the same
 * way a viewer proves it at registration — an SMS sent FROM that phone to verify.mn. The check is opened only after
 * a correct password ({@link #open}), is bound to that phone and to {@code ADMIN_LOGIN}, can be spent once, and
 * runs out ({@link PhoneVerificationPurpose#ADMIN_LOGIN}'s claim window, the provider's own expiry).
 */
@Service
public class AdminLoginServiceImpl implements AdminSecondStep, AdminLoginService {

    static final String NOT_VERIFIED = VerifiedPhoneClaim.NOT_VERIFIED;

    private final AdminPhoneCheck phoneChecks;
    private final VerifiedPhoneClaim verifiedPhones;
    private final UserRepository users;
    private final LoginAttemptLimiter loginLimiter;
    private final JwtService jwt;
    private final MeMapper meMapper;
    private final AdminLoginMapper mapper;
    private final DomainEventPublisher events;

    public AdminLoginServiceImpl(AdminPhoneCheck phoneChecks, VerifiedPhoneClaim verifiedPhones, UserRepository users,
                                 LoginAttemptLimiter loginLimiter, JwtService jwt, MeMapper meMapper,
                                 AdminLoginMapper mapper, DomainEventPublisher events) {
        this.phoneChecks = phoneChecks;
        this.verifiedPhones = verifiedPhones;
        this.users = users;
        this.loginLimiter = loginLimiter;
        this.jwt = jwt;
        this.meMapper = meMapper;
        this.mapper = mapper;
        this.events = events;
    }

    @Override
    public AdminLoginChallenge open(UserEntity admin) {
        return mapper.toChallenge(phoneChecks.openForAdminLogin(admin.getPhoneNumber()));
    }

    @Override
    @Transactional
    public AuthResponse verify(AdminLoginVerifyReq req) {
        String phone = req.phoneNumber();
        loginLimiter.requireNotLocked(phone);
        UserEntity admin = users.findByPhoneNumber(phone)
                .filter(u -> u.getRole() == Role.ADMIN)
                .orElseThrow(() -> refusal(phone));
        try {
            verifiedPhones.claim(req.verificationId(), phone, PhoneVerificationPurpose.ADMIN_LOGIN);
        } catch (BadRequestException e) {
            throw refusal(phone);
        }
        loginLimiter.recordSuccess(phone);
        events.publish(new AdminSignedIn(admin.getId()));
        return new AuthResponse(jwt.issue(admin), meMapper.toMe(admin));
    }

    /** Counts towards the same lock as wrong passwords, and says nothing about why. */
    private BadRequestException refusal(String phone) {
        loginLimiter.recordFailure(phone);
        return new BadRequestException(NOT_VERIFIED);
    }
}
