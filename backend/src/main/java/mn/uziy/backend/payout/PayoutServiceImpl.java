package mn.uziy.backend.payout;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PayoutServiceImpl implements PayoutService {

    static final String USER_NOT_FOUND = Messages.USER_NOT_FOUND;
    static final String INSUFFICIENT_BALANCE = Messages.INSUFFICIENT_BALANCE;
    static final String PAYOUT_NOT_FOUND = "Мөнгө татах хүсэлт олдсонгүй";
    static final String ALREADY_DECIDED = "Энэ хүсэлтийг аль хэдийн шийдвэрлэсэн байна";
    static final String ACTION_PENDING = "VIEW_PAYOUTS";
    static final String ACTION_HISTORY = "VIEW_PAYOUT_HISTORY";

    private final PayoutRepository payouts;
    private final UserRepository users;
    private final PayoutRuleChain requestRules;
    private final PayoutDecisionStrategies decisionStrategies;
    private final PayoutMapper mapper;
    private final DomainEventPublisher events;
    private final Clock clock;
    private final DataAccessLogRepository accessLog;

    public PayoutServiceImpl(
            PayoutRepository payouts,
            UserRepository users,
            PayoutRuleChain requestRules,
            PayoutDecisionStrategies decisionStrategies,
            PayoutMapper mapper,
            DomainEventPublisher events,
            Clock clock,
            DataAccessLogRepository accessLog) {
        this.payouts = payouts;
        this.users = users;
        this.requestRules = requestRules;
        this.decisionStrategies = decisionStrategies;
        this.mapper = mapper;
        this.events = events;
        this.clock = clock;
        this.accessLog = accessLog;
    }

    @Override
    @Transactional
    public PayoutDto request(long userId, CreatePayoutReq req) {
        UserEntity user = users.findById(userId).orElseThrow(() -> new NotFoundException(USER_NOT_FOUND));
        requestRules.validate(user, req);

        // Any prior APPROVED payout => not a first payout.
        boolean isFirst = !payouts.existsByUserIdAndStatus(user.getId(), PayoutStatus.APPROVED);

        // Reserve the amount by decrementing balance immediately so it can't
        // be spent twice while the request is PENDING. Refund on rejection.
        // One conditional UPDATE: the rules above are a friendly early answer, this is what makes it safe
        // when several requests race for the same balance.
        if (users.tryDeductBalance(user.getId(), req.amount()) == 0) {
            throw new BadRequestException(INSUFFICIENT_BALANCE);
        }

        PayoutEntity p = new PayoutEntity();
        p.setUserId(user.getId());
        p.setAmount(req.amount());
        p.setBank(req.bank());
        p.setAccountNumber(req.accountNumber());
        p.setAccountName(req.accountName());
        p.setFirstPayout(isFirst);
        PayoutDto dto = mapper.toDto(payouts.save(p), user.getPhoneNumber());
        events.publish(new PayoutRequested(dto.id(), dto.userId(), dto.amount()));
        return dto;
    }

    @Override
    public List<PayoutDto> mine(long userId) {
        UserEntity user = users.findById(userId).orElseThrow(() -> new NotFoundException(USER_NOT_FOUND));
        return payouts.findAllByUserIdOrderByRequestedAtDesc(user.getId()).stream()
                .map(p -> mapper.toDto(p, user.getPhoneNumber()))
                .toList();
    }

    @Override
    @Transactional
    public List<PayoutDto> pending(long adminId) {
        accessLog.record(adminId, ACTION_PENDING, "");
        return withPhones(payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING));
    }

    @Override
    @Transactional
    public List<PayoutDto> history(long adminId) {
        accessLog.record(adminId, ACTION_HISTORY, "");
        return withPhones(payouts.findAllByStatusInOrderByDecidedAtDesc(
                List.of(PayoutStatus.APPROVED, PayoutStatus.REJECTED)));
    }

    @Override
    @Transactional
    public PayoutDto decide(long payoutId, PayoutStatus decision, @Nullable String reason, long adminId) {
        PayoutDecisionStrategy strategy = decisionStrategies.forDecision(decision); // rejects PENDING

        if (!payouts.existsById(payoutId)) {
            throw new NotFoundException(PAYOUT_NOT_FOUND);
        }
        // Claim first: only one decision can ever move this payout out of PENDING.
        if (payouts.tryClaim(payoutId, decision) == 0) {
            throw new ConflictException(ALREADY_DECIDED);
        }

        PayoutEntity p = payouts.findById(payoutId).orElseThrow(() -> new NotFoundException(PAYOUT_NOT_FOUND));
        UserEntity user = users.findById(p.getUserId()).orElseThrow(() -> new NotFoundException(USER_NOT_FOUND));
        strategy.apply(user, p, reason);
        users.save(user);

        p.setStatus(decision);
        p.setDecidedBy(adminId);
        p.setDecidedAt(OffsetDateTime.now(clock));
        PayoutDto dto = mapper.toAdminDto(payouts.save(p), user.getPhoneNumber());
        events.publish(new PayoutDecided(dto.id(), dto.userId(), decision, adminId));
        return dto;
    }

    private List<PayoutDto> withPhones(List<PayoutEntity> list) {
        List<Long> userIds = list.stream().map(PayoutEntity::getUserId).distinct().toList();
        Map<Long, String> phoneById = users.findAllById(userIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, UserEntity::getPhoneNumber, (a, b) -> a));
        return list.stream()
                .map(p -> mapper.toAdminDto(p, phoneById.getOrDefault(p.getUserId(), "")))
                .toList();
    }
}
