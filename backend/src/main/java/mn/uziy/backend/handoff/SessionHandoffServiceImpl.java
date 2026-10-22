package mn.uziy.backend.handoff;

import java.time.Clock;
import java.time.Duration;
import java.time.OffsetDateTime;
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.trusteddevice.DeviceSecrets;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The code is {@value DeviceSecrets#SECRET_BYTES} random bytes, lives {@link #CODE_LIFETIME} and is spent once by
 * a conditional UPDATE; only its SHA-256 is stored. The admin's password and SMS were already proved on the login
 * page, so the code proves nothing new — it only carries that session across.
 */
@Service
public class SessionHandoffServiceImpl implements SessionHandoffService {

    static final Duration CODE_LIFETIME = Duration.ofSeconds(60);
    static final String INVALID = Messages.HANDOFF_INVALID;

    private final SessionHandoffRepository handoffs;
    private final UserRepository users;
    private final DeviceSecrets secrets;
    private final JwtService jwt;
    private final MeMapper meMapper;
    private final DomainEventPublisher events;
    private final Clock clock;

    public SessionHandoffServiceImpl(SessionHandoffRepository handoffs, UserRepository users, DeviceSecrets secrets,
                                     JwtService jwt, MeMapper meMapper, DomainEventPublisher events, Clock clock) {
        this.handoffs = handoffs;
        this.users = users;
        this.secrets = secrets;
        this.jwt = jwt;
        this.meMapper = meMapper;
        this.events = events;
        this.clock = clock;
    }

    @Override
    @Transactional
    public HandoffCode create(long adminId) {
        OffsetDateTime now = OffsetDateTime.now(clock);
        handoffs.deleteExpiredBefore(now);
        String code = secrets.next();
        OffsetDateTime expiresAt = now.plus(CODE_LIFETIME);
        handoffs.insert(adminId, DeviceSecrets.hash(code), now, expiresAt);
        return new HandoffCode(code, expiresAt);
    }

    @Override
    @Transactional
    public AuthResponse redeem(@Nullable String code) {
        if (code == null || code.isBlank() || code.length() > DeviceSecrets.MAX_SECRET_LENGTH) {
            throw new BadRequestException(INVALID);
        }
        long userId = handoffs.trySpend(DeviceSecrets.hash(code), OffsetDateTime.now(clock))
                .orElseThrow(() -> new BadRequestException(INVALID));
        UserEntity admin = users.findById(userId)
                .filter(u -> u.getRole() == Role.ADMIN)
                .orElseThrow(() -> new BadRequestException(INVALID));
        events.publish(new SessionHandedOff(admin.getId()));
        return new AuthResponse(jwt.issue(admin), meMapper.toMe(admin));
    }
}
