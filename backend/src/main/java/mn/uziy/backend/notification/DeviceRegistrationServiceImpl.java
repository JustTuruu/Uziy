package mn.uziy.backend.notification;

import java.time.Clock;
import java.time.OffsetDateTime;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Pattern: Service layer — token upsert; owns the transaction. */
@Service
public class DeviceRegistrationServiceImpl implements DeviceRegistrationService {

    private final DeviceTokenRepository tokens;
    private final Clock clock;

    public DeviceRegistrationServiceImpl(DeviceTokenRepository tokens, Clock clock) {
        this.tokens = tokens;
        this.clock = clock;
    }

    @Override
    @Transactional
    public void register(long userId, String token, DevicePlatform platform) {
        DeviceTokenEntity entity = tokens.findByToken(token).orElseGet(DeviceTokenEntity::new);
        entity.setToken(token);
        entity.setUserId(userId);
        entity.setPlatform(platform);
        entity.setUpdatedAt(OffsetDateTime.now(clock));
        if (entity.getId() == null) {
            entity.setCreatedAt(entity.getUpdatedAt());
        }
        tokens.save(entity);
    }

    @Override
    @Transactional
    public void unregister(long userId, String token) {
        tokens.deleteByUserIdAndToken(userId, token);
    }
}
