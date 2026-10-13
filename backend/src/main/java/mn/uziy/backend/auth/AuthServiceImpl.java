package mn.uziy.backend.auth;

import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.phoneverify.VerifiedPhoneClaim;
import mn.uziy.backend.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthServiceImpl implements AuthService {

    public static final String INVALID_CREDENTIALS = "Invalid credentials";
    public static final String PHONE_TAKEN = "Phone already registered";

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final UserFactory userFactory;
    private final MeMapper meMapper;
    private final DomainEventPublisher events;
    private final VerifiedPhoneClaim verifiedPhones;
    private final LoginAttemptLimiter loginLimiter;

    public AuthServiceImpl(UserRepository users, PasswordEncoder encoder, JwtService jwt,
                           UserFactory userFactory, MeMapper meMapper, DomainEventPublisher events,
                           VerifiedPhoneClaim verifiedPhones, LoginAttemptLimiter loginLimiter) {
        this.verifiedPhones = verifiedPhones;
        this.loginLimiter = loginLimiter;
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.userFactory = userFactory;
        this.meMapper = meMapper;
        this.events = events;
    }

    @Override
    public AuthResponse login(LoginReq req) {
        loginLimiter.requireNotLocked(req.phoneNumber());
        UserEntity user = users.findByPhoneNumber(req.phoneNumber()).orElse(null);
        if (user == null || !encoder.matches(req.password(), user.getPasswordHash())) {
            // An unknown phone counts too, so the lock is the same for every number.
            loginLimiter.recordFailure(req.phoneNumber());
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        loginLimiter.recordSuccess(req.phoneNumber());
        return respond(user);
    }

    /** One transaction: a refused save gives the phone check back instead of spending it. */
    @Override
    @Transactional
    public AuthResponse registerViewer(RegisterViewerReq req) {
        requirePhoneFree(req.phoneNumber());
        verifiedPhones.claim(req.verificationId(), req.phoneNumber());
        UserEntity user = userFactory.newViewer(req, encoder.encode(req.password()));
        return registered(users.save(user));
    }

    @Override
    public AuthResponse registerCompany(RegisterCompanyReq req) {
        requirePhoneFree(req.phoneNumber());
        UserEntity user = userFactory.newCompany(req, encoder.encode(req.password()));
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
