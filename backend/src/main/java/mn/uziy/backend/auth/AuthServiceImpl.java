package mn.uziy.backend.auth;

import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.UnauthorizedException;
import mn.uziy.backend.domain.Role;
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

    public AuthServiceImpl(UserRepository users, PasswordEncoder encoder, JwtService jwt) {
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
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
        UserEntity user = new UserEntity();
        user.setPhoneNumber(req.phoneNumber());
        user.setPasswordHash(encoder.encode(req.password()));
        user.setRole(Role.VIEWER);
        user.setGender(req.gender());
        user.setBirthDate(req.birthDate());
        user.setCity(req.city());
        user.setDistrict(req.district());
        return respond(users.save(user));
    }

    @Override
    public AuthResponse registerCompany(RegisterCompanyReq req) {
        requirePhoneFree(req.phoneNumber());
        UserEntity user = new UserEntity();
        user.setPhoneNumber(req.phoneNumber());
        user.setPasswordHash(encoder.encode(req.password()));
        user.setRole(Role.COMPANY);
        user.setCompanyName(req.companyName());
        return respond(users.save(user));
    }

    private void requirePhoneFree(String phone) {
        if (users.existsByPhoneNumber(phone)) {
            throw new ConflictException(PHONE_TAKEN);
        }
    }

    private AuthResponse respond(UserEntity user) {
        return new AuthResponse(jwt.issue(user), Me.of(user));
    }
}
