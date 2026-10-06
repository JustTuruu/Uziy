package mn.uziy.backend.auth;

import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

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

    public AuthServiceImpl(UserRepository users, PasswordEncoder encoder, JwtService jwt,
                           UserFactory userFactory, MeMapper meMapper, DomainEventPublisher events) {
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.userFactory = userFactory;
        this.meMapper = meMapper;
        this.events = events;
    }

    @Override
    public AuthResponse login(LoginReq req) {
        UserEntity user = users.findByPhoneNumber(req.phoneNumber())
                .orElseThrow(() -> new UnauthorizedException(INVALID_CREDENTIALS));
        if (!encoder.matches(req.password(), user.getPasswordHash())) {
            throw new UnauthorizedException(INVALID_CREDENTIALS);
        }
        return respond(user);
    }

    @Override
    public AuthResponse registerViewer(RegisterViewerReq req) {
        requirePhoneFree(req.phoneNumber());
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
