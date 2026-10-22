package mn.uziy.backend.handoff;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
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
import mn.uziy.backend.auth.AuthResponse;
import mn.uziy.backend.auth.MeMapper;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.security.JwtService;
import mn.uziy.backend.trusteddevice.DeviceSecrets;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class SessionHandoffServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-22T04:00:00Z");
    private static final OffsetDateTime NOW_UTC = OffsetDateTime.ofInstant(NOW, ZoneOffset.UTC);

    private final SessionHandoffRepository handoffs = mock(SessionHandoffRepository.class);
    private final UserRepository users = mock(UserRepository.class);
    private final JwtService jwt = mock(JwtService.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final SessionHandoffServiceImpl service = new SessionHandoffServiceImpl(handoffs, users,
            new DeviceSecrets(), jwt, new MeMapper(), events, Clock.fixed(NOW, ZoneOffset.UTC));

    private static UserEntity user(long id, Role role) {
        UserEntity u = new UserEntity();
        u.setId(id);
        u.setRole(role);
        u.setPhoneNumber("88112233");
        return u;
    }

    @Test
    void aCodeLivesSixtySecondsAndOnlyItsHashIsStored() {
        HandoffCode out = service.create(7L);

        assertThat(out.code()).hasSize(43);
        assertThat(out.expiresAt()).isEqualTo(NOW_UTC.plusSeconds(60));
        ArgumentCaptor<String> stored = ArgumentCaptor.forClass(String.class);
        verify(handoffs).insert(eq(7L), stored.capture(), eq(NOW_UTC), eq(NOW_UTC.plusSeconds(60)));
        assertThat(stored.getValue()).isEqualTo(DeviceSecrets.hash(out.code())).isNotEqualTo(out.code());
        verify(handoffs).deleteExpiredBefore(NOW_UTC);
    }

    @Test
    void everyCodeIsDifferent() {
        assertThat(service.create(7L).code()).isNotEqualTo(service.create(7L).code());
    }

    @Test
    void spendingAValidCodeSignsTheAdminIn() {
        String code = "c".repeat(43);
        when(handoffs.trySpend(DeviceSecrets.hash(code), NOW_UTC)).thenReturn(Optional.of(7L));
        when(users.findById(7L)).thenReturn(Optional.of(user(7L, Role.ADMIN)));
        when(jwt.issue(any())).thenReturn("admin-jwt");

        AuthResponse res = service.redeem(code);

        assertThat(res.token()).isEqualTo("admin-jwt");
        assertThat(res.user().role()).isEqualTo(Role.ADMIN);
        verify(events).publish(new SessionHandedOff(7L));
    }

    @Test
    void anUnknownSpentOrExpiredCodeIsOneSentence() {
        when(handoffs.trySpend(anyString(), any())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.redeem("c".repeat(43)))
                .isInstanceOf(BadRequestException.class)
                .hasMessage(SessionHandoffServiceImpl.INVALID);
        verifyNoInteractions(jwt, events);
    }

    @Test
    void aCodeWhoseAccountIsNoLongerAnAdminSignsNobodyIn() {
        when(handoffs.trySpend(anyString(), any())).thenReturn(Optional.of(7L));
        when(users.findById(7L)).thenReturn(Optional.of(user(7L, Role.COMPANY)));

        assertThatThrownBy(() -> service.redeem("c".repeat(43)))
                .hasMessage(SessionHandoffServiceImpl.INVALID);
        verifyNoInteractions(jwt);
    }

    @Test
    void aMissingOrOversizedCodeIsNotEvenLookedUp() {
        for (String bad : new String[] {null, " ", "x".repeat(DeviceSecrets.MAX_SECRET_LENGTH + 1)}) {
            assertThatThrownBy(() -> service.redeem(bad)).hasMessage(SessionHandoffServiceImpl.INVALID);
        }
        verify(handoffs, never()).trySpend(anyString(), any());
    }

    @Test
    void theEventCarriesIdsOnly() {
        assertThat(new SessionHandedOff(7L).toString()).doesNotContain("88112233");
    }
}
