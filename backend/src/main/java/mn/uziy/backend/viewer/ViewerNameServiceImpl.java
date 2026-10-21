package mn.uziy.backend.viewer;

import mn.uziy.backend.auth.Me;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ViewerNameServiceImpl implements ViewerNameService {

    private final UserRepository users;
    private final MeMapper meMapper;
    private final DomainEventPublisher events;

    public ViewerNameServiceImpl(UserRepository users, MeMapper meMapper, DomainEventPublisher events) {
        this.users = users;
        this.meMapper = meMapper;
        this.events = events;
    }

    @Override
    @Transactional
    public Me setNameOnce(long viewerId, String lastName, String firstName) {
        int changed = users.trySetNameOnce(viewerId, Role.VIEWER, lastName.strip(), firstName.strip());
        UserEntity user = users.findById(viewerId).orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
        if (changed == 0) {
            throw new ConflictException(Messages.NAME_ALREADY_SET);
        }
        events.publish(new ViewerNameSet(viewerId));
        return meMapper.toMe(user);
    }
}
