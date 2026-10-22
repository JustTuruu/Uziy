package mn.uziy.backend.account;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.PayoutRepository;
import mn.uziy.backend.domain.PayoutStatus;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.security.crypto.password.PasswordEncoder;

class AccountDeletionServiceImplTest {

    private static final long VIEWER = 42L;
    private static final String PHONE = "99112233";
    private static final String HASH = "$2a$10$hash";
    private static final Instant NOW = Instant.parse("2026-10-22T04:05:06.789Z");

    private final UserRepository users = mock(UserRepository.class);
    private final PayoutRepository payouts = mock(PayoutRepository.class);
    private final AccountDeletionRepository deletion = mock(AccountDeletionRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final AccountDeletionServiceImpl service = new AccountDeletionServiceImpl(users, payouts, deletion,
            encoder, events, Clock.fixed(NOW, ZoneOffset.UTC));

    private static UserEntity user(Role role) {
        UserEntity u = new UserEntity();
        u.setId(VIEWER);
        u.setPhoneNumber(PHONE);
        u.setPasswordHash(HASH);
        u.setRole(role);
        return u;
    }

    @BeforeEach
    void aViewerWithTheRightPassword() {
        when(users.findById(VIEWER)).thenReturn(Optional.of(user(Role.VIEWER)));
        when(encoder.matches("secret12", HASH)).thenReturn(true);
        when(deletion.tryAnonymiseViewer(eq(VIEWER), eq(HASH), anyString(), anyString(), any())).thenReturn(1);
    }

    @Test
    void theRowIsAnonymisedWithATombstonePhoneAndAllItsTokensDie() {
        service.deleteOwnAccount(VIEWER, "secret12");

        verify(deletion).tryAnonymiseViewer(VIEWER, HASH, "DEL-42", AccountDeletionServiceImpl.UNUSABLE_PASSWORD_HASH,
                OffsetDateTime.parse("2026-10-22T04:05:07Z"));
    }

    @Test
    void pushTokensPhoneChecksFreeTextAndPayoutAccountsAreCleanedAndTheEventCarriesOnlyTheId() {
        service.deleteOwnAccount(VIEWER, "secret12");

        verify(deletion).deleteDeviceTokens(VIEWER);
        verify(deletion).deletePhoneVerifications(PHONE);
        verify(deletion).deleteFreeTextAnswers(VIEWER);
        verify(deletion).maskPayoutAccounts(VIEWER, "••••", 4);
        verify(events).publish(new ViewerDeleted(VIEWER));
    }

    @Test
    void theRowIsLockedByTheUpdateBeforeLookingForAPendingPayout() {
        service.deleteOwnAccount(VIEWER, "secret12");

        InOrder order = inOrder(deletion, payouts);
        order.verify(deletion).tryAnonymiseViewer(anyLong(), anyString(), anyString(), anyString(), any());
        order.verify(payouts).existsByUserIdAndStatus(VIEWER, PayoutStatus.PENDING);
    }

    @Test
    void aWrongPasswordChangesNothing() {
        assertThatThrownBy(() -> service.deleteOwnAccount(VIEWER, "wrong"))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(AccountDeletionMessages.WRONG_PASSWORD);

        verifyNoInteractions(deletion, events);
    }

    @Test
    void aPendingPayoutRefusesTheDeletionSoTheTransactionRollsBack() {
        when(payouts.existsByUserIdAndStatus(VIEWER, PayoutStatus.PENDING)).thenReturn(true);

        assertThatThrownBy(() -> service.deleteOwnAccount(VIEWER, "secret12"))
                .isInstanceOf(ConflictException.class)
                .hasMessage(AccountDeletionMessages.PAYOUT_PENDING);

        verify(deletion, never()).deleteDeviceTokens(anyLong());
        verify(events, never()).publish(any());
    }

    @Test
    void aRowThatChangedInBetweenIsNotDeleted() {
        when(deletion.tryAnonymiseViewer(eq(VIEWER), eq(HASH), anyString(), anyString(), any())).thenReturn(0);

        assertThatThrownBy(() -> service.deleteOwnAccount(VIEWER, "secret12"))
                .isInstanceOf(ConflictException.class)
                .hasMessage(AccountDeletionMessages.NOT_DELETED);

        verify(events, never()).publish(any());
    }

    @Test
    void onlyViewerAccountsCanBeDeletedHere() {
        when(users.findById(VIEWER)).thenReturn(Optional.of(user(Role.COMPANY)));

        assertThatThrownBy(() -> service.deleteOwnAccount(VIEWER, "secret12"))
                .isInstanceOf(NotFoundException.class);
        verifyNoInteractions(deletion);
    }

    @Test
    void tombstonesAreUniquePerRowFitTheColumnAndAreNeverAPhoneNumber() {
        String longest = AccountDeletionServiceImpl.tombstonePhone(99_999_999_999L);

        assertThat(longest).hasSizeLessThanOrEqualTo(15).doesNotMatch("\\d{8}");
        assertThat(AccountDeletionServiceImpl.tombstonePhone(1))
                .isNotEqualTo(AccountDeletionServiceImpl.tombstonePhone(2));
    }
}
