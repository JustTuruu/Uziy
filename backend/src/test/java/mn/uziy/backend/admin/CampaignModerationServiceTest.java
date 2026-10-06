package mn.uziy.backend.admin;

import static mn.uziy.backend.admin.AdminTestData.campaign;
import static mn.uziy.backend.admin.AdminTestData.company;
import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.company.CampaignStatusChanged;
import mn.uziy.backend.company.CampaignMapper;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.UserRepository;
import mn.uziy.backend.domain.ViewHistoryRepository;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;

class CampaignModerationServiceTest {

    private final UserRepository users = mock(UserRepository.class);
    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final ViewHistoryRepository history = mock(ViewHistoryRepository.class);
    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-06T10:00:00Z"), ZoneOffset.UTC);
    private final CampaignModerationServiceImpl moderation = new CampaignModerationServiceImpl(
            campaigns, users, history, new AdminCampaignMapper(new CampaignMapper()),
            new ModerationStrategyRegistry(List.of(new ApproveCampaignStrategy(), new RejectCampaignStrategy())),
            events, clock);

    // ------- listCampaigns -------------------------------------------------

    @Test
    void listCampaignsWithoutStatusReturnsAll() {
        when(campaigns.findAll()).thenReturn(List.of(
                campaign(1, CampaignStatus.ACTIVE),
                campaign(2, CampaignStatus.PAUSED)));
        assertThat(moderation.list(null, null)).hasSize(2);
    }

    @Test
    void listCampaignsWithStatusFiltersByStatus() {
        when(campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING))
                .thenReturn(List.of(campaign(1, CampaignStatus.PENDING)));
        List<CampaignDto> list = moderation.list(CampaignStatus.PENDING, null);
        assertThat(list).hasSize(1);
        assertThat(list.get(0).status()).isEqualTo(CampaignStatus.PENDING);
    }

    @Test
    void listCampaignsWithCompanyIdReturnsOnlyThatCompanysCampaigns() {
        when(campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L)).thenReturn(List.of(
                campaign(1, CampaignStatus.ACTIVE),
                campaign(2, CampaignStatus.PAUSED)));
        assertThat(moderation.list(null, 500L)).hasSize(2);
    }

    @Test
    void listCampaignsWithCompanyIdAndStatusFiltersBoth() {
        when(campaigns.findAllByCompanyIdOrderByCreatedAtDesc(500L)).thenReturn(List.of(
                campaign(1, CampaignStatus.ACTIVE),
                campaign(2, CampaignStatus.PAUSED),
                campaign(3, CampaignStatus.ACTIVE)));
        List<CampaignDto> list = moderation.list(CampaignStatus.ACTIVE, 500L);
        assertThat(list).hasSize(2);
        assertThat(list).allMatch(c -> c.status() == CampaignStatus.ACTIVE);
    }

    // ------- getCampaign ---------------------------------------------------

    @Test
    void getCampaignReturnsDetailWithCompletionCountAndCompanyName() {
        when(campaigns.findById(9L)).thenReturn(Optional.of(campaign(9, CampaignStatus.ACTIVE)));
        when(users.findById(500L)).thenReturn(Optional.of(company(500L, "MobiCom")));
        when(history.countByCampaignId(9L)).thenReturn(42L);

        CampaignDetailDto d = moderation.get(9L);

        assertThat(d.campaign().id()).isEqualTo(9L);
        assertThat(d.companyId()).isEqualTo(500L);
        assertThat(d.companyName()).isEqualTo("MobiCom");
        assertThat(d.completedViews()).isEqualTo(42L);
        assertThat(d.spentBudget()).isEqualTo(100_000.0); // 1,000,000 total - 900,000 remaining
    }

    @Test
    void getCampaign404sWhenTheCampaignDoesNotExist() {
        when(campaigns.findById(anyLong())).thenReturn(Optional.empty());
        var ex = assertFailsWithHttp(() -> moderation.get(999L));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void getCampaignToleratesAMissingOwningCompany() {
        when(campaigns.findById(10L)).thenReturn(Optional.of(campaign(10, CampaignStatus.ACTIVE)));
        when(users.findById(500L)).thenReturn(Optional.empty());
        when(history.countByCampaignId(10L)).thenReturn(0L);

        assertThat(moderation.get(10L).companyName()).isNull();
    }

    // ------- moderate ------------------------------------------------------

    @Test
    void moderateActiveApprovesAPendingCampaign() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.PENDING)));
        ArgumentCaptor<CampaignEntity> saved = ArgumentCaptor.forClass(CampaignEntity.class);
        when(campaigns.save(saved.capture())).thenAnswer(inv -> inv.getArgument(0));

        CampaignDto dto = moderation.moderate(1L, CampaignStatus.ACTIVE);

        assertThat(dto.status()).isEqualTo(CampaignStatus.ACTIVE);
        assertThat(saved.getValue().getStatus()).isEqualTo(CampaignStatus.ACTIVE);
        assertThat(saved.getValue().getUpdatedAt()).isEqualTo(OffsetDateTime.now(clock));
    }

    @Test
    void moderatePublishesCampaignStatusChangedWithAdminActor() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.PENDING)));
        when(campaigns.save(any())).thenAnswer(inv -> inv.getArgument(0));

        moderation.moderate(1L, CampaignStatus.REJECTED);

        verify(events).publish(new CampaignStatusChanged(
                1L, CampaignStatus.PENDING, CampaignStatus.REJECTED, CampaignActor.ADMIN));
    }

    @Test
    void failedModerationPublishesNothing() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.ACTIVE)));
        assertFailsWithHttp(() -> moderation.moderate(1L, CampaignStatus.ACTIVE));
        verifyNoInteractions(events);
    }

    @Test
    void moderateRejectedRejectsAPendingCampaign() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.PENDING)));
        when(campaigns.save(any())).thenAnswer(inv -> inv.getArgument(0));

        assertThat(moderation.moderate(1L, CampaignStatus.REJECTED).status())
                .isEqualTo(CampaignStatus.REJECTED);
    }

    @Test
    void moderateRejectsInvalidDecisionsLikePaused() {
        var ex = assertFailsWithHttp(() -> moderation.moderate(1L, CampaignStatus.PAUSED));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void moderate409sForAnUnpaidAwaitingPaymentCampaign() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.AWAITING_PAYMENT)));
        var ex = assertFailsWithHttp(() -> moderation.moderate(1L, CampaignStatus.ACTIVE));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        assertThat(ex.reason()).isEqualTo(CampaignModerationServiceImpl.UNPAID_MESSAGE);
        verify(campaigns, never()).save(any());
    }

    @Test
    void moderate404sWhenTheCampaignDoesNotExist() {
        when(campaigns.findById(anyLong())).thenReturn(Optional.empty());
        var ex = assertFailsWithHttp(() -> moderation.moderate(1L, CampaignStatus.ACTIVE));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void campaignDtosExposeCommissionSnapshotAndPaidAt() {
        OffsetDateTime paidAt = OffsetDateTime.now();
        CampaignEntity c = campaign(9, CampaignStatus.PENDING);
        c.setCommissionPercent(30);
        c.setTargetViewers(1000);
        c.setPaidAt(paidAt);
        when(campaigns.findAllByStatusOrderByCreatedAtDesc(CampaignStatus.PENDING)).thenReturn(List.of(c));

        CampaignDto dto = moderation.list(CampaignStatus.PENDING, null).get(0);

        assertThat(dto.commissionPercent()).isEqualTo(30);
        assertThat(dto.targetViewers()).isEqualTo(1000);
        assertThat(dto.paidAt()).isEqualTo(paidAt);
    }

    @Test
    void moderate409sWhenCampaignIsNotPending() {
        when(campaigns.findById(1L)).thenReturn(Optional.of(campaign(1, CampaignStatus.ACTIVE)));
        var ex = assertFailsWithHttp(() -> moderation.moderate(1L, CampaignStatus.ACTIVE));
        assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
    }
}
