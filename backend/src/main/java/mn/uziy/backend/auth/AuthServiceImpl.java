package mn.uziy.backend.auth;

import java.time.Clock;
import java.time.LocalDate;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.consolelogin.ConsoleLoginGate;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.PhoneVerificationPurpose;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthServiceImpl implements AuthService {

    public static final String INVALID_CREDENTIALS = "Утасны дугаар эсвэл нууц үг буруу байна";
    public static final String PHONE_TAKEN = Messages.PHONE_TAKEN;

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final UserFactory userFactory;
    private final MeMapper meMapper;
    private final DomainEventPublisher events;
    private final VerifiedPhoneClaim verifiedPhones;
    private final LoginAttemptLimiter loginLimiter;
    private final Clock clock;
    private final ConsoleLoginGate consoleLogin;

    public AuthServiceImpl(UserRepository users, PasswordEncoder encoder, JwtService jwt,
                           UserFactory userFactory, MeMapper meMapper, DomainEventPublisher events,
                           VerifiedPhoneClaim verifiedPhones, LoginAttemptLimiter loginLimiter, Clock clock,
                           ConsoleLoginGate consoleLogin) {
        this.clock = clock;
        this.consoleLogin = consoleLogin;
        this.verifiedPhones = verifiedPhones;
        this.loginLimiter = loginLimiter;
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.userFactory = userFactory;
        this.meMapper = meMapper;
        this.events = events;
    }

    /**
     * The password is always proved first, so a wrong one never leads to an SMS. Viewers are then signed in; admins
     * and companies are signed in only from a browser they proved their phone from, else they get the SMS step.
     */
    @Override
    public LoginOutcome login(LoginReq req) {
        loginLimiter.requireNotLocked(req.phoneNumber());
        UserEntity user = users.findByPhoneNumber(req.phoneNumber()).orElse(null);
        if (user == null || !encoder.matches(req.password(), user.getPasswordHash())) {
            // An unknown phone counts too, so the lock is the same for every number.
            loginLimiter.recordFailure(req.phoneNumber());
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        loginLimiter.recordSuccess(req.phoneNumber());
        if (consoleLogin.appliesTo(user.getRole())) {
            return consoleLogin.afterPassword(user, req.deviceToken());
        }
        return new LoginOutcome.SignedIn(respond(user));
    }

    /** One transaction: a refused save gives the phone check back instead of spending it. */
    @Override
    @Transactional
    public AuthResponse registerViewer(RegisterViewerReq req) {
        requirePhoneFree(req.phoneNumber());
        ViewerLocationRule.check(req.city(), req.district());
        ViewerAgeRule.check(req.birthDate(), LocalDate.now(clock));
        verifiedPhones.claim(req.verificationId(), req.phoneNumber(), PhoneVerificationPurpose.REGISTER);
        UserEntity user = userFactory.newViewer(req, encoder.encode(req.password()));
        return registered(users.save(user));
    }

    private void requirePhoneFree(String phone) {
        if (users.existsByPhoneNumber(phone)) {
            throw new ConflictException(PHONE_TAKEN);
        }
    }

    private AuthResponse registered(UserEntity saved) {
        events.publish(new UserRegistered(saved.getId(), saved.getRole()));
        return respond(saved);
    }

    private AuthResponse respond(UserEntity user) {
        return new AuthResponse(jwt.issue(user), meMapper.toMe(user));
    }
}
