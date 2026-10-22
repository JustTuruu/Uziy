package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.auth.UserFactory;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Company accounts are made only here (audit 2026-10-22): an open sign-up let anyone take a viewer's phone number
 * and spend the server's BCrypt time. A race on the same phone still ends in the unique index (409).
 */
@Service
public class CompanyAccountServiceImpl implements CompanyAccountService {

    static final String PHONE_TAKEN = Messages.ACCOUNT_PHONE_TAKEN;
    static final String ACTION_LIST = "VIEW_COMPANIES";

    private final UserRepository users;
    private final CompanyAccountRepository companies;
    private final UserFactory userFactory;
    private final PasswordEncoder encoder;
    private final CompanyAccountMapper mapper;
    private final DomainEventPublisher events;
    private final DataAccessLogRepository accessLog;

    public CompanyAccountServiceImpl(UserRepository users, CompanyAccountRepository companies,
                                     UserFactory userFactory, PasswordEncoder encoder, CompanyAccountMapper mapper,
                                     DomainEventPublisher events, DataAccessLogRepository accessLog) {
        this.users = users;
        this.companies = companies;
        this.userFactory = userFactory;
        this.encoder = encoder;
        this.mapper = mapper;
        this.events = events;
        this.accessLog = accessLog;
    }

    @Override
    @Transactional
    public CompanyAccountDto create(CreateCompanyReq req, long adminId) {
        if (users.existsByPhoneNumber(req.phoneNumber())) {
            throw new ConflictException(PHONE_TAKEN);
        }
        UserEntity company = users.save(
                userFactory.newCompany(req.phoneNumber(), req.companyName(), encoder.encode(req.password())));
        events.publish(new CompanyCreated(company.getId(), adminId));
        return mapper.toDto(company);
    }

    @Override
    @Transactional
    public List<CompanyAccountDto> list(long adminId) {
        accessLog.record(adminId, ACTION_LIST, "");
        return companies.listWithCampaignCounts().stream().map(mapper::toDto).toList();
    }
}
