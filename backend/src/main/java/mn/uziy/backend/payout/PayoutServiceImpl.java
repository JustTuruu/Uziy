package mn.uziy.backend.payout;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.jspecify.annotations.Nullable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PayoutServiceImpl implements PayoutService {

    private final PayoutRepository payouts;
    private final UserRepository users;
    private final PayoutRuleChain requestRules;
    private final PayoutDecisionStrategies decisionStrategies;
    private final PayoutMapper mapper;
    private final DomainEventPublisher events;
    private final Clock clock;

    public PayoutServiceImpl(
            PayoutRepository payouts,
            UserRepository users,
            PayoutRuleChain requestRules,
            PayoutDecisionStrategies decisionStrategies,
            PayoutMapper mapper,
            DomainEventPublisher events,
            Clock clock) {
        this.payouts = payouts;
        this.users = users;
        this.requestRules = requestRules;
        this.decisionStrategies = decisionStrategies;
        this.mapper = mapper;
        this.events = events;
        this.clock = clock;
    }

    @Override
    @Transactional
    public PayoutDto request(long userId, CreatePayoutReq req) {
        UserEntity user = users.findById(userId).orElseThrow();
        requestRules.validate(user, req);

        // Any prior APPROVED payout => not a first payout.
        boolean isFirst = !payouts.existsByUserIdAndStatus(user.getId(), PayoutStatus.APPROVED);

        // Reserve the amount by decrementing balance immediately so it can't
        // be spent twice while the request is PENDING. Refund on rejection.
        user.setBalance(user.getBalance() - req.amount());
        users.save(user);

        PayoutEntity p = new PayoutEntity();
        p.setUserId(user.getId());
        p.setAmount(req.amount());
        p.setBank(req.bank());
        p.setAccountNumber(req.accountNumber());
        p.setAccountName(req.accountName());
        p.setNationalId(req.nationalId());
        p.setFirstPayout(isFirst);
        PayoutDto dto = mapper.toDto(payouts.save(p), user.getPhoneNumber());
        events.publish(new PayoutRequested(dto.id(), dto.userId(), dto.amount()));
        return dto;
    }

    @Override
    public List<PayoutDto> mine(long userId) {
        UserEntity user = users.findById(userId).orElseThrow();
        return payouts.findAllByUserIdOrderByRequestedAtDesc(user.getId()).stream()
                .map(p -> mapper.toDto(p, user.getPhoneNumber()))
                .toList();
    }

    @Override
    public List<PayoutDto> pending() {
        return withPhones(payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING));
    }

    @Override
    public List<PayoutDto> history() {
        return withPhones(payouts.findAllByStatusInOrderByDecidedAtDesc(
                List.of(PayoutStatus.APPROVED, PayoutStatus.REJECTED)));
    }

    @Override
    @Transactional
    public PayoutDto decide(long payoutId, PayoutStatus decision, @Nullable String reason, long adminId) {
        PayoutDecisionStrategy strategy = decisionStrategies.forDecision(decision); // rejects PENDING

        PayoutEntity p = payouts.findById(payoutId).orElseThrow();
        if (p.getStatus() != PayoutStatus.PENDING) {
            throw new ConflictException("Already decided");
        }

        UserEntity user = users.findById(p.getUserId()).orElseThrow();
        strategy.apply(user, p, reason);
        users.save(user);

        p.setStatus(decision);
        p.setDecidedBy(adminId);
        p.setDecidedAt(OffsetDateTime.now(clock));
        PayoutDto dto = mapper.toDto(payouts.save(p), user.getPhoneNumber());
        events.publish(new PayoutDecided(dto.id(), dto.userId(), decision, adminId));
        return dto;
    }

    private List<PayoutDto> withPhones(List<PayoutEntity> list) {
        List<Long> userIds = list.stream().map(PayoutEntity::getUserId).distinct().toList();
        Map<Long, String> phoneById = users.findAllById(userIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, UserEntity::getPhoneNumber, (a, b) -> a));
        return list.stream()
                .map(p -> mapper.toDto(p, phoneById.getOrDefault(p.getUserId(), "")))
                .toList();
    }
}
