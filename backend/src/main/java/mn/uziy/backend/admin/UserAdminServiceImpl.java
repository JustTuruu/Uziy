package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserAdminServiceImpl implements UserAdminService {

    private final UserRepository users;
    static final String ACTION_LIST = "VIEW_USERS";
    static final String ACTION_GET = "VIEW_USER";

    private final UserMapper mapper;
    private final DataAccessLogRepository accessLog;

    public UserAdminServiceImpl(UserRepository users, UserMapper mapper, DataAccessLogRepository accessLog) {
        this.users = users;
        this.mapper = mapper;
        this.accessLog = accessLog;
    }

    @Override
    @Transactional
    public List<UserDto> list(long adminId) {
        accessLog.record(adminId, ACTION_LIST, "");
        return users.findAll().stream().map(mapper::toDto).toList();
    }

    @Override
    @Transactional
    public UserDto get(long userId, long adminId) {
        UserDto user = mapper.toDto(load(userId));
        accessLog.record(adminId, ACTION_GET, "user=" + userId);
        return user;
    }

    /** One UPDATE of the flag only: saving a loaded copy back could overwrite a balance changed meanwhile. */
    @Override
    @Transactional
    public UserDto verify(long userId) {
        if (users.markVerified(userId) == 0) {
            throw new NotFoundException(Messages.USER_NOT_FOUND);
        }
        return mapper.toDto(load(userId));
    }

    private UserEntity load(long userId) {
        return users.findById(userId).orElseThrow(() -> new NotFoundException(Messages.USER_NOT_FOUND));
    }
}
