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

class CompanyAccountServiceTest {

    private static final long ADMIN = 1L;
    private static final OffsetDateTime CREATED = OffsetDateTime.parse("2026-10-22T04:00:00Z");

    private final UserRepository users = mock(UserRepository.class);
    private final CompanyAccountRepository companies = mock(CompanyAccountRepository.class);
    private final PasswordEncoder encoder = mock(PasswordEncoder.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final DataAccessLogRepository accessLog = mock(DataAccessLogRepository.class);
    private final CompanyAccountServiceImpl service = new CompanyAccountServiceImpl(users, companies,
            new UserFactory(), encoder, new CompanyAccountMapper(), events, accessLog);

    private static CreateCompanyReq req() {
        return new CreateCompanyReq(" MobiCom ", "88112233", "temp-pass1");
    }

    @Test
    void createsACompanyAccountWithAHashedPasswordAndAnnouncesIt() {
        when(encoder.encode("temp-pass1")).thenReturn("bcrypt");
        when(users.save(any(UserEntity.class))).thenAnswer(inv -> {
            UserEntity u = inv.getArgument(0);
            u.setId(77L);
            u.setCreatedAt(CREATED);
            return u;
        });

        CompanyAccountDto dto = service.create(req(), ADMIN);

        assertThat(dto).isEqualTo(new CompanyAccountDto(77L, "MobiCom", "88112233", CREATED, 0));
        ArgumentCaptor<UserEntity> saved = ArgumentCaptor.forClass(UserEntity.class);
        verify(users).save(saved.capture());
        assertThat(saved.getValue().getRole()).isEqualTo(Role.COMPANY);
        assertThat(saved.getValue().getPasswordHash()).isEqualTo("bcrypt");
        assertThat(saved.getValue().getBalance()).isZero();
        verify(events).publish(new CompanyCreated(77L, ADMIN));
    }

    @Test
    void aTakenPhoneIs409AndHashesNothing() {
        when(users.existsByPhoneNumber("88112233")).thenReturn(true);

        assertThatThrownBy(() -> service.create(req(), ADMIN))
                .isInstanceOf(ConflictException.class)
                .hasMessage(CompanyAccountServiceImpl.PHONE_TAKEN);
        verify(users, never()).save(any());
        verifyNoInteractions(encoder, events);
    }

    @Test
    void listsCompaniesWithTheirSurveyCountsAndLogsTheRead() {
        when(companies.listWithCampaignCounts()).thenReturn(List.of(
                new CompanyListing(5L, "MobiCom", "88112233", CREATED, 3),
                new CompanyListing(6L, null, "88112234", CREATED, 0)));

        List<CompanyAccountDto> list = service.list(ADMIN);

        assertThat(list).containsExactly(
                new CompanyAccountDto(5L, "MobiCom", "88112233", CREATED, 3),
                new CompanyAccountDto(6L, "", "88112234", CREATED, 0));
        verify(accessLog).record(ADMIN, CompanyAccountServiceImpl.ACTION_LIST, "");
    }

    @Test
    void theEventCarriesIdsOnly() {
        assertThat(new CompanyCreated(77L, ADMIN).toString()).doesNotContain("88112233");
    }
}
