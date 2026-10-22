package mn.uziy.backend.payout;

import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.PayoutEntity;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import mn.uziy.backend.security.JwtPrincipal;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class PayoutServiceTest {

    private final PayoutRepository payouts = mock(PayoutRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-06T00:00:00Z"), ZoneOffset.UTC);
    private final DataAccessLogRepository accessLog = mock(DataAccessLogRepository.class);
    private final PayoutServiceImpl service = new PayoutServiceImpl(
            payouts, users,
            new PayoutRuleChain(List.of(new MinimumPayoutRule(), new SufficientBalanceRule())),
            new PayoutDecisionStrategies(List.of(new ApprovePayoutStrategy(), new RejectPayoutStrategy(users))),
            new PayoutMapper(), events, clock, accessLog);

    private final UserEntity viewer = newViewer();
    private final JwtPrincipal viewerPrincipal = new JwtPrincipal(42L, Role.VIEWER);
    private final JwtPrincipal adminPrincipal = new JwtPrincipal(1L, Role.ADMIN);

    private static UserEntity newViewer() {
        UserEntity u = new UserEntity();
        u.setId(42L);
        u.setPhoneNumber("77000001");
        u.setPasswordHash("x");
        u.setRole(Role.VIEWER);
        u.setBalance(7500.0);
        u.setVerified(false);
        return u;
    }

    private static CreatePayoutReq reqBody(double amount) {
        return new CreatePayoutReq(amount, "Khan Bank", "5001234567", "БОЛД ЭРДЭНЭ");
    }

    private static PayoutEntity payout(long id, double amount, PayoutStatus status, boolean first) {
        PayoutEntity p = new PayoutEntity();
        p.setId(id);
        p.setUserId(42L);
        p.setAmount(amount);
        p.setBank("Khan");
        p.setAccountNumber("5001234567");
        p.setAccountName("X");
        p.setStatus(status);
        p.setFirstPayout(first);
        return p;
    }

    private ArgumentCaptor<UserEntity> stubUserSave() {
        ArgumentCaptor<UserEntity> savedUser = ArgumentCaptor.forClass(UserEntity.class);
        when(users.save(savedUser.capture())).thenAnswer(inv -> inv.getArgument(0));
        return savedUser;
    }

    private ArgumentCaptor<PayoutEntity> stubPayoutSave() {
        ArgumentCaptor<PayoutEntity> savedPayout = ArgumentCaptor.forClass(PayoutEntity.class);
        when(payouts.save(savedPayout.capture())).thenAnswer(inv -> inv.getArgument(0));
        return savedPayout;
    }

    // ------- viewer.request ------------------------------------------------

    @Test
    void requestReservesBalanceAtomicallyAndMarksFirstPayout() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(users.tryDeductBalance(42L, 5000.0)).thenReturn(1);
        when(payouts.existsByUserIdAndStatus(42L, PayoutStatus.APPROVED)).thenReturn(false);
        when(payouts.save(any())).thenAnswer(inv -> {
            PayoutEntity p = inv.getArgument(0);
            p.setId(1L);
            return p;
        });

        PayoutDto dto = service.request(viewerPrincipal.userId(), reqBody(5000.0));

        assertThat(dto.id()).isEqualTo(1L);
        assertThat(dto.isFirstPayout()).isTrue();
        assertThat(dto.status()).isEqualTo(PayoutStatus.PENDING);
        verify(users).tryDeductBalance(42L, 5000.0);
        verify(users, never()).save(any());
        verify(events).publish(new PayoutRequested(1L, 42L, 5000.0));
    }

    @Test
    void requestThrows400OnInsufficientBalance() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        var ex = assertFailsWithHttp(() -> service.request(viewerPrincipal.userId(), reqBody(9999.0)));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(payouts, never()).save(any());
        verify(users, never()).tryDeductBalance(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void requestLosingTheRaceForTheBalanceIsRefusedAndRecordsNothing() {
        // The balance looked big enough when read, but another request spent it first.
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(users.tryDeductBalance(42L, 5000.0)).thenReturn(0);

        var ex = assertFailsWithHttp(() -> service.request(viewerPrincipal.userId(), reqBody(5000.0)));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(payouts, never()).save(any());
        verify(events, never()).publish(any());
    }

    @Test
    void requestBelowTheMinimumOrWithFractionsIsRefused() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));

        assertThat(assertFailsWithHttp(() -> service.request(42L, reqBody(4999.0))).statusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(assertFailsWithHttp(() -> service.request(42L, reqBody(5000.5))).statusCode())
                .isEqualTo(HttpStatus.BAD_REQUEST);
        verify(users, never()).tryDeductBalance(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void requestMarksIsFirstPayoutFalseWhenUserHasAPriorApprovedPayout() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(users.tryDeductBalance(42L, 5000.0)).thenReturn(1);
        when(payouts.existsByUserIdAndStatus(42L, PayoutStatus.APPROVED)).thenReturn(true);
        when(payouts.save(any())).thenAnswer(inv -> {
            PayoutEntity p = inv.getArgument(0);
            p.setId(2L);
            return p;
        });

        PayoutDto dto = service.request(viewerPrincipal.userId(), reqBody(5000.0));
        assertThat(dto.isFirstPayout()).isFalse();
    }

    @Test
    void requestForAMissingUserIs404() {
        when(users.findById(42L)).thenReturn(Optional.empty());

        assertThat(assertFailsWithHttp(() -> service.request(42L, reqBody(5000.0))).statusCode())
                .isEqualTo(HttpStatus.NOT_FOUND);
    }

    // ------- viewer.mine ---------------------------------------------------

    @Test
    void mineReturnsOwnPayoutsNewestFirst() {
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        when(payouts.findAllByUserIdOrderByRequestedAtDesc(42L))
                .thenReturn(List.of(payout(1L, 500.0, PayoutStatus.PENDING, false)));
        List<PayoutDto> list = service.mine(viewerPrincipal.userId());
        assertThat(list).hasSize(1);
        assertThat(list.get(0).status()).isEqualTo(PayoutStatus.PENDING);
    }

    // ------- admin.pending -------------------------------------------------

    @Test
    void adminPendingListIsEnrichedWithUserPhoneNumbers() {
        when(payouts.findAllByStatusOrderByRequestedAtAsc(PayoutStatus.PENDING))
                .thenReturn(List.of(payout(10L, 500.0, PayoutStatus.PENDING, false)));
        when(users.findAllById(List.of(42L))).thenReturn(List.of(viewer));

        List<PayoutDto> list = service.pending(adminPrincipal.userId());
        assertThat(list).hasSize(1);
        assertThat(list.get(0).userPhone()).isEqualTo("77000001");
        // Still to be paid: the admin needs the whole number.
        assertThat(list.get(0).accountNumber()).isEqualTo("5001234567");
        verify(accessLog).record(1L, PayoutServiceImpl.ACTION_PENDING, "");
    }

    // ------- admin.history -------------------------------------------------

    @Test
    void adminHistoryReturnsApprovedAndRejectedPayoutsWithPhoneNumbers() {
        PayoutEntity rejected = payout(21L, 700.0, PayoutStatus.REJECTED, false);
        rejected.setRejectReason("name mismatch");
        when(payouts.findAllByStatusInOrderByDecidedAtDesc(List.of(PayoutStatus.APPROVED, PayoutStatus.REJECTED)))
                .thenReturn(List.of(payout(20L, 500.0, PayoutStatus.APPROVED, false), rejected));
        when(users.findAllById(List.of(42L))).thenReturn(List.of(viewer));

        List<PayoutDto> list = service.history(adminPrincipal.userId());
        assertThat(list).hasSize(2);
        assertThat(list).extracting(PayoutDto::accountNumber).containsOnly("•••• 4567");
        verify(accessLog).record(1L, PayoutServiceImpl.ACTION_HISTORY, "");
        assertThat(list.get(0).status()).isEqualTo(PayoutStatus.APPROVED);
        assertThat(list.get(1).status()).isEqualTo(PayoutStatus.REJECTED);
        assertThat(list.get(0).userPhone()).isEqualTo("77000001");
    }

    @Test
    void adminHistoryOmitsPendingPayouts() {
        when(payouts.findAllByStatusInOrderByDecidedAtDesc(List.of(PayoutStatus.APPROVED, PayoutStatus.REJECTED)))
                .thenReturn(List.of());
        when(users.findAllById(List.of())).thenReturn(List.of());

        assertThat(service.history(adminPrincipal.userId())).isEmpty();
    }

    // ------- admin.decide --------------------------------------------------

    private void claimable(long id, PayoutEntity p) {
        when(payouts.existsById(id)).thenReturn(true);
        when(payouts.tryClaim(org.mockito.ArgumentMatchers.eq(id), any())).thenReturn(1);
        when(payouts.findById(id)).thenReturn(Optional.of(p));
    }

    @Test
    void decideApprovedOnFirstPayoutFlipsIsVerifiedToTrue() {
        PayoutEntity p = payout(10L, 500.0, PayoutStatus.PENDING, true);
        claimable(10L, p);
        viewer.setVerified(false);
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        ArgumentCaptor<UserEntity> savedUser = stubUserSave();
        ArgumentCaptor<PayoutEntity> savedPayout = stubPayoutSave();

        service.decide(10L, PayoutStatus.APPROVED, null, adminPrincipal.userId());

        assertThat(savedUser.getValue().isVerified()).isTrue();
        assertThat(savedPayout.getValue().getStatus()).isEqualTo(PayoutStatus.APPROVED);
        assertThat(savedPayout.getValue().getDecidedBy()).isEqualTo(1L);
        assertThat(savedPayout.getValue().getDecidedAt()).isEqualTo(OffsetDateTime.now(clock));
        verify(payouts).tryClaim(10L, PayoutStatus.APPROVED);
        verify(events).publish(new PayoutDecided(10L, 42L, PayoutStatus.APPROVED, 1L));
    }

    @Test
    void decideApprovedOnRepeatPayoutKeepsIsVerifiedAsItWas() {
        PayoutEntity p = payout(11L, 500.0, PayoutStatus.PENDING, false);
        claimable(11L, p);
        viewer.setVerified(false);
        viewer.setBalance(1000.0);
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        ArgumentCaptor<UserEntity> savedUser = stubUserSave();
        when(payouts.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.decide(11L, PayoutStatus.APPROVED, null, adminPrincipal.userId());

        assertThat(savedUser.getValue().getBalance()).isEqualTo(1000.0);
        assertThat(savedUser.getValue().isVerified()).isFalse();
        verify(users, never()).addBalance(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void decideRejectedRefundsTheReservedBalanceWithAnAtomicCredit() {
        PayoutEntity p = payout(12L, 500.0, PayoutStatus.PENDING, true);
        claimable(12L, p);
        when(users.findById(42L)).thenReturn(Optional.of(viewer));
        stubUserSave();
        when(payouts.save(any())).thenAnswer(inv -> inv.getArgument(0));

        service.decide(12L, PayoutStatus.REJECTED, "wrong name", adminPrincipal.userId());

        verify(users).addBalance(42L, 500.0);
        assertThat(p.getRejectReason()).isEqualTo("wrong name");
    }

    @Test
    void decideThrows400WhenTargetStatusIsPending() {
        var ex = assertFailsWithHttp(
                () -> service.decide(1L, PayoutStatus.PENDING, null, adminPrincipal.userId()));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void decideThrows409WhenSomeoneElseAlreadyDecidedThePayout() {
        when(payouts.existsById(13L)).thenReturn(true);
        when(payouts.tryClaim(13L, PayoutStatus.REJECTED)).thenReturn(0); // lost the claim

        var ex = assertFailsWithHttp(
                () -> service.decide(13L, PayoutStatus.REJECTED, null, adminPrincipal.userId()));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        verify(users, never()).addBalance(org.mockito.ArgumentMatchers.anyLong(),
                org.mockito.ArgumentMatchers.anyDouble());
    }

    @Test
    void decideThrows404ForAPayoutThatDoesNotExist() {
        when(payouts.existsById(14L)).thenReturn(false);

        var ex = assertFailsWithHttp(
                () -> service.decide(14L, PayoutStatus.APPROVED, null, adminPrincipal.userId()));

        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verify(payouts, never()).tryClaim(org.mockito.ArgumentMatchers.anyLong(), any());
    }
}
