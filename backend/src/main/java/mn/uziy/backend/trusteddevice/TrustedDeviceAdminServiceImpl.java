package mn.uziy.backend.trusteddevice;

import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TrustedDeviceAdminServiceImpl implements TrustedDeviceAdminService {

    private final UserRepository users;
    private final TrustedDeviceRevoker revoker;
    private final DomainEventPublisher events;

    public TrustedDeviceAdminServiceImpl(UserRepository users, TrustedDeviceRevoker revoker,
                                         DomainEventPublisher events) {
        this.users = users;
        this.revoker = revoker;
        this.events = events;
    }

    @Override
    @Transactional
    public void forgetAll(long userId, long adminId) {
        if (!users.existsById(userId)) {
            throw new NotFoundException(Messages.USER_NOT_FOUND);
        }
        int forgotten = revoker.revokeAll(userId);
        events.publish(new TrustedDevicesForgotten(userId, adminId, forgotten));
    }
}
