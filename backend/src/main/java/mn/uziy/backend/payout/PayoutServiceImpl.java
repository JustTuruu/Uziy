package mn.uziy.backend.payout;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
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

    public PayoutServiceImpl(PayoutRepository payouts, UserRepository users) {
        this.payouts = payouts;
        this.users = users;
    }

    @Override
    @Transactional
    public PayoutDto request(long userId, CreatePayoutReq req) {
        UserEntity user = users.findById(userId).orElseThrow();
        if (user.getBalance() < req.amount()) {
            throw new BadRequestException("Insufficient balance");
        }

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
        return toDto(payouts.save(p), user.getPhoneNumber());
    }

    @Override
    public List<PayoutDto> mine(long userId) {
        UserEntity user = users.findById(userId).orElseThrow();
        return payouts.findAllByUserIdOrderByRequestedAtDesc(user.getId()).stream()
                .map(p -> toDto(p, user.getPhoneNumber()))
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
        if (decision == PayoutStatus.PENDING) {
            throw new BadRequestException("Cannot set PENDING");
        }

        PayoutEntity p = payouts.findById(payoutId).orElseThrow();
        if (p.getStatus() != PayoutStatus.PENDING) {
            throw new ConflictException("Already decided");
        }

        UserEntity user = users.findById(p.getUserId()).orElseThrow();
        if (decision == PayoutStatus.APPROVED) {
            if (p.isFirstPayout()) {
                user.setVerified(true);
            }
            users.save(user);
        } else if (decision == PayoutStatus.REJECTED) {
            user.setBalance(user.getBalance() + p.getAmount()); // refund the reservation
            users.save(user);
        }

        p.setStatus(decision);
        p.setRejectReason(decision == PayoutStatus.REJECTED ? reason : null);
        p.setDecidedBy(adminId);
        p.setDecidedAt(OffsetDateTime.now());
        return toDto(payouts.save(p), user.getPhoneNumber());
    }

    private List<PayoutDto> withPhones(List<PayoutEntity> list) {
        List<Long> userIds = list.stream().map(PayoutEntity::getUserId).distinct().toList();
        Map<Long, String> phoneById = users.findAllById(userIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, UserEntity::getPhoneNumber, (a, b) -> a));
        return list.stream()
                .map(p -> toDto(p, phoneById.getOrDefault(p.getUserId(), "")))
                .toList();
    }

    private PayoutDto toDto(PayoutEntity p, String phone) {
        return new PayoutDto(
                p.getId(), p.getUserId(), phone,
                p.getAmount(), p.getBank(), p.getAccountNumber(),
                p.getAccountName(), p.getNationalId(),
                p.getStatus(), p.isFirstPayout(),
                p.getRequestedAt(), p.getDecidedAt(),
                p.getRejectReason());
    }
}
