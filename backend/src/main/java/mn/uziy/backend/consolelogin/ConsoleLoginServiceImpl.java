package mn.uziy.backend.consolelogin;

import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.LoginAttemptLimiter;
import mn.uziy.backend.auth.LoginOutcome;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.LoginPhoneCheck;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.trusteddevice.DeviceTrust;
import mn.uziy.backend.trusteddevice.IssuedDevice;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * A console account's password alone is not enough on a browser the server does not know (owner, 2026-10-22, for
 * admins and companies): the account's phone must also be proved, the way a viewer proves it at registration — an
 * SMS sent FROM that phone to verify.mn. The check is opened only after a correct password, is bound to that phone
 * and to the role's own purpose ({@code ADMIN_LOGIN} / {@code COMPANY_LOGIN}), can be spent once and runs out (the
 * purpose's claim window, the provider's own expiry). A proved browser is then remembered ({@link DeviceTrust}) and
 * skips this step next time; the password is always asked.
 */
@Service
public class ConsoleLoginServiceImpl implements ConsoleLoginGate, ConsoleLoginService {

    static final String NOT_VERIFIED = VerifiedPhoneClaim.NOT_VERIFIED;

    private final LoginPhoneCheck phoneChecks;
    private final VerifiedPhoneClaim verifiedPhones;
    private final DeviceTrust devices;
    private final UserRepository users;
    private final LoginAttemptLimiter loginLimiter;
    private final JwtService jwt;
    private final MeMapper meMapper;
    private final ConsoleLoginMapper mapper;
    private final DomainEventPublisher events;

    public ConsoleLoginServiceImpl(LoginPhoneCheck phoneChecks, VerifiedPhoneClaim verifiedPhones,
                                   DeviceTrust devices, UserRepository users, LoginAttemptLimiter loginLimiter,
                                   JwtService jwt, MeMapper meMapper, ConsoleLoginMapper mapper,
                                   DomainEventPublisher events) {
        this.phoneChecks = phoneChecks;
        this.verifiedPhones = verifiedPhones;
        this.devices = devices;
        this.users = users;
        this.loginLimiter = loginLimiter;
        this.jwt = jwt;
        this.meMapper = meMapper;
        this.mapper = mapper;
        this.events = events;
    }

    @Override
    public boolean appliesTo(Role role) {
        return PhoneVerificationPurpose.loginStepFor(role).isPresent();
    }

    @Override
    public LoginOutcome afterPassword(UserEntity user, @Nullable String deviceToken) {
        PhoneVerificationPurpose purpose = loginStepOf(user.getRole());
        if (devices.recognises(user.getId(), deviceToken)) {
            events.publish(new ConsoleSignedIn(user.getId(), user.getRole(), false));
            return new LoginOutcome.SignedIn(respond(user));
        }
        return new LoginOutcome.SecondStepRequired(
                mapper.toChallenge(phoneChecks.openForLogin(user.getPhoneNumber(), purpose), user.getRole()));
    }

    @Override
    @Transactional
    public ConsoleLoginVerifiedRes verify(ConsoleLoginVerifyReq req, @Nullable String userAgent) {
        String phone = req.phoneNumber();
        loginLimiter.requireNotLocked(phone);
        UserEntity user = users.findByPhoneNumber(phone)
                .filter(u -> appliesTo(u.getRole()))
                .orElseThrow(() -> refusal(phone));
        try {
            verifiedPhones.claim(req.verificationId(), phone, loginStepOf(user.getRole()));
        } catch (BadRequestException e) {
            throw refusal(phone);
        }
        loginLimiter.recordSuccess(phone);
        IssuedDevice device = devices.trust(user.getId(), userAgent);
        events.publish(new ConsoleSignedIn(user.getId(), user.getRole(), true));
        AuthResponse signedIn = respond(user);
        return new ConsoleLoginVerifiedRes(signedIn.token(), signedIn.user(), device.secret(), device.trustedUntil());
    }

    private static PhoneVerificationPurpose loginStepOf(Role role) {
        return PhoneVerificationPurpose.loginStepFor(role)
                .orElseThrow(() -> new IllegalArgumentException("no console login for " + role));
    }

    private AuthResponse respond(UserEntity user) {
        return new AuthResponse(jwt.issue(user), meMapper.toMe(user));
    }

    /** Counts towards the same lock as wrong passwords, and says nothing about why. */
    private BadRequestException refusal(String phone) {
        loginLimiter.recordFailure(phone);
        return new BadRequestException(NOT_VERIFIED);
    }
}
