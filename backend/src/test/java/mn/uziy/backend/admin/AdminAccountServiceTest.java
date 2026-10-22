package mn.uziy.backend.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.util.List;
import mn.uziy.backend.auth.UserFactory;
import mn.uziy.backend.common.ConflictException;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.domain.Role;
import mn.uziy.backend.domain.UserEntity;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.insights.DataAccessLogRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.security.crypto.password.PasswordEncoder;

class AdminAccountServiceTest {

    private static final long ADMIN = 1L;
    private static final OffsetDateTime CREATED = OffsetDateTime.parse("2026-10-22T04:00:00Z");

    private final UserRepository users = mock(UserRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final DataAccessLogRepository accessLog = mock(DataAccessLogRepository.class);
    private final AdminAccountServiceImpl service = new AdminAccountServiceImpl(users, new UserFactory(), encoder,
            new AdminAccountMapper(), events, accessLog);

    private static CreateAdminReq req() {
        return new CreateAdminReq("88112233", "temp-pass1");
    }

    private static UserEntity admin(long id, String phone) {
        UserEntity u = new UserEntity();
        u.setId(id);
        u.setRole(Role.ADMIN);
        u.setPhoneNumber(phone);
        u.setCreatedAt(CREATED);
        return u;
    }

    @Test
    void createsAnAdminAccountWithAHashedPasswordAndAnnouncesIt() {
        when(encoder.encode("temp-pass1")).thenReturn("bcrypt");
        when(users.save(any(UserEntity.class))).thenAnswer(inv -> {
            UserEntity u = inv.getArgument(0);
            u.setId(77L);
            u.setCreatedAt(CREATED);
            return u;
        });

        AdminAccountDto dto = service.create(req(), ADMIN);

        assertThat(dto).isEqualTo(new AdminAccountDto(77L, "88112233", CREATED));
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(Role.ADMIN);
        assertThat(saved.getValue().getPasswordHash()).isEqualTo("bcrypt");
        assertThat(saved.getValue().getBalance()).isZero();
        verify(events).publish(new AdminCreated(77L, ADMIN));
    }

    @Test
    void aTakenPhoneIs409AndNoExistingAccountIsPromoted() {
        when(users.existsByPhoneNumber("88112233")).thenReturn(true);

        assertThatThrownBy(() -> service.create(req(), ADMIN))
                .isInstanceOf(ConflictException.class)
                .hasMessage(AdminAccountServiceImpl.PHONE_TAKEN);
        verify(users, never()).save(any());
        verifyNoInteractions(encoder, events);
    }

    @Test
    void listsAdminsNewestFirstAndLogsTheRead() {
        when(users.findByRoleOrderByCreatedAtDescIdDesc(Role.ADMIN))
                .thenReturn(List.of(admin(6L, "88112234"), admin(5L, "88112233")));

        assertThat(service.list(ADMIN)).containsExactly(
                new AdminAccountDto(6L, "88112234", CREATED),
                new AdminAccountDto(5L, "88112233", CREATED));
        verify(accessLog).record(ADMIN, AdminAccountServiceImpl.ACTION_LIST, "");
    }

    @Test
    void theEventCarriesIdsOnly() {
        assertThat(new AdminCreated(77L, ADMIN).toString()).doesNotContain("88112233");
    }
}
