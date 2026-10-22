package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.auth.UserFactory;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Admin accounts are made only here, by a signed-in admin. An existing account (a viewer's, a company's) is never
 * promoted: a phone that is taken is 409, so a role change can only happen in the database on purpose. A race on
 * the same phone still ends in the unique index (409).
 */
@Service
public class AdminAccountServiceImpl implements AdminAccountService {

    static final String PHONE_TAKEN = Messages.ACCOUNT_PHONE_TAKEN;
    static final String ACTION_LIST = "VIEW_ADMINS";

    private final UserRepository users;
    private final UserFactory userFactory;
    private final PasswordEncoder encoder;
    private final AdminAccountMapper mapper;
    private final DomainEventPublisher events;
    private final DataAccessLogRepository accessLog;

    public AdminAccountServiceImpl(UserRepository users, UserFactory userFactory, PasswordEncoder encoder,
                                   AdminAccountMapper mapper, DomainEventPublisher events,
                                   DataAccessLogRepository accessLog) {
        this.users = users;
        this.userFactory = userFactory;
        this.encoder = encoder;
        this.mapper = mapper;
        this.events = events;
        this.accessLog = accessLog;
    }

    @Override
    @Transactional
    public AdminAccountDto create(CreateAdminReq req, long adminId) {
        if (users.existsByPhoneNumber(req.phoneNumber())) {
            throw new ConflictException(PHONE_TAKEN);
        }
        UserEntity admin = users.save(userFactory.newAdmin(req.phoneNumber(), encoder.encode(req.password())));
        events.publish(new AdminCreated(admin.getId(), adminId));
        return mapper.toDto(admin);
    }

    @Override
    @Transactional
    public List<AdminAccountDto> list(long adminId) {
        accessLog.record(adminId, ACTION_LIST, "");
        return users.findByRoleOrderByCreatedAtDescIdDesc(Role.ADMIN).stream().map(mapper::toDto).toList();
    }
}
