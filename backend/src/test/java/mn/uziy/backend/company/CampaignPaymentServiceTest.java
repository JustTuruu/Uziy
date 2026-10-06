package mn.uziy.backend.company;

import static mn.uziy.backend.company.CompanyTestFixtures.PRINCIPAL;
import static mn.uziy.backend.company.CompanyTestFixtures.sampleCampaign;
import static mn.uziy.backend.support.HttpAssertions.assertFailsWithHttp;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import mn.uziy.backend.common.event.DomainEventPublisher;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.CampaignActor;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignPaymentRepository;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.PaymentStatus;
import mn.uziy.backend.payment.PaymentReference;
import mn.uziy.backend.payment.PaymentGatewaySelector;
import mn.uziy.backend.payment.SimulatedPaymentGateway;
import mn.uziy.backend.support.HttpAssertions.HttpFailure;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;

class CampaignPaymentServiceTest {

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final CampaignPaymentRepository payments = mock(CampaignPaymentRepository.class);

    private final DomainEventPublisher events = mock(DomainEventPublisher.class);
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-01T10:15:30.123456789Z"), ZoneOffset.UTC);

    private final CampaignPaymentServiceImpl paymentSvc = paymentService(true);
    private final long companyId = PRINCIPAL.userId();

    private CampaignPaymentServiceImpl paymentService(boolean simulated) {
        return new CampaignPaymentServiceImpl(campaigns, payments,
                new PaymentGatewaySelector(List.of(new SimulatedPaymentGateway(
                        new AppProperties(new AppProperties.Jwt("", 24), new AppProperties.Cors(List.of()),
                                new AppProperties.Payments(simulated),
                                new AppProperties.Push(false, ""))))),
                new CampaignFactory(), new CampaignMapper(), new PaymentMapper(), events, clock);
    }

    private CampaignEntity awaiting(long id, long ownerId) {
        CampaignEntity c = sampleCampaign(id, ownerId, CampaignStatus.AWAITING_PAYMENT);
        c.setTotalBudget(999_570.0);
        c.setRemainingBudget(999_570.0);
        return c;
    }

    @Nested
    class Pay {

        @Test
        void happyPathMarksPendingAndRecordsASimulatedPaidPayment() {
            when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting(42L, 500L)));
            when(campaigns.tryMarkPaid(eq(42L), any())).thenReturn(1);
            AtomicReference<CampaignPaymentEntity> payment = new AtomicReference<>();
            when(payments.saveAndFlush(any(CampaignPaymentEntity.class))).thenAnswer(inv -> {
                CampaignPaymentEntity e = inv.getArgument(0);
                e.setId(9L);
                payment.set(e);
                return e;
            });

            PayCampaignResponse res = paymentSvc.pay(companyId, 42L);

            CampaignPaymentEntity p = payment.get();
            assertThat(p.getCampaignId()).isEqualTo(42L);
            assertThat(p.getCompanyId()).isEqualTo(500L);
            assertThat(p.getAmount()).isEqualTo(999_570.0);
            assertThat(p.getProvider()).isEqualTo(PaymentProvider.SIMULATED);
            assertThat(p.getStatus()).isEqualTo(PaymentStatus.PAID);
            assertThat(p.getPaidAt()).isNotNull();
            assertThat(p.getReference()).isEqualTo(PaymentReference.of(42L, p.getPaidAt()));
            assertThat(p.getReference()).matches("UZ-\\d{8}-42");

            assertThat(res.campaign().status()).isEqualTo(CampaignStatus.PENDING);
            assertThat(res.campaign().paidAt()).isEqualTo(p.getPaidAt());
            assertThat(res.payment().id()).isEqualTo(9L);
            assertThat(res.payment().campaignTitle()).isEqualTo("T42");
            assertThat(res.payment().amount()).isEqualTo(999_570.0);
            assertThat(p.getPaidAt()).isEqualTo(Instant.parse("2026-10-01T10:15:30.123456Z").atOffset(ZoneOffset.UTC));
            verify(events).publish(new CampaignPaid(42L, 500L, 999_570.0, p.getReference()));
            verify(events).publish(new CampaignStatusChanged(
                    42L, CampaignStatus.AWAITING_PAYMENT, CampaignStatus.PENDING, CampaignActor.SYSTEM));
            verify(campaigns, times(1)).tryMarkPaid(42L, p.getPaidAt());
            verify(campaigns, never()).save(any());
        }

        @Test
        void notFound404WhenTheCampaignDoesNotExist() {
            when(campaigns.findById(any())).thenReturn(Optional.empty());
            HttpFailure ex = assertFailsWithHttp(() -> paymentSvc.pay(companyId, 1L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        }

        @Test
        void forbidden403ForAnotherCompanysCampaignNothingIsMarkedPaid() {
            when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting(42L, 999L)));
            HttpFailure ex = assertFailsWithHttp(() -> paymentSvc.pay(companyId, 42L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.FORBIDDEN);
            verify(campaigns, never()).tryMarkPaid(anyLong(), any());
            verify(payments, never()).saveAndFlush(any());
        }

        @ParameterizedTest
        @CsvSource({"PENDING", "ACTIVE", "PAUSED", "COMPLETED", "REJECTED"})
        void conflict409UnlessAwaitingPayment(CampaignStatus status) {
            when(campaigns.findById(42L)).thenReturn(Optional.of(sampleCampaign(42L, 500L, status)));
            HttpFailure ex = assertFailsWithHttp(() -> paymentSvc.pay(companyId, 42L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
            assertThat(ex.reason()).isEqualTo(CompanyMessages.NOT_PAYABLE_MESSAGE);
            verify(campaigns, never()).tryMarkPaid(anyLong(), any());
            verify(events, never()).publish(any());
        }

        @Test
        void conflict409WhenAConcurrentPaymentWonTheConditionalUpdate() {
            when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting(42L, 500L)));
            when(campaigns.tryMarkPaid(eq(42L), any())).thenReturn(0);
            HttpFailure ex = assertFailsWithHttp(() -> paymentSvc.pay(companyId, 42L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
            verify(payments, never()).saveAndFlush(any());
            verify(events, never()).publish(any());
        }

        @Test
        void conflict409WhenTheOnePaidRowUniqueIndexFires() {
            when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting(42L, 500L)));
            when(campaigns.tryMarkPaid(eq(42L), any())).thenReturn(1);
            when(payments.saveAndFlush(any())).thenThrow(
                    new DataIntegrityViolationException("ux_campaign_payments_one_paid"));
            HttpFailure ex = assertFailsWithHttp(() -> paymentSvc.pay(companyId, 42L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.CONFLICT);
        }

        @Test
        void unavailable503WhenSimulatedPaymentsAreSwitchedOff() {
            when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting(42L, 500L)));
            HttpFailure ex = assertFailsWithHttp(() -> paymentService(false).pay(companyId, 42L));
            assertThat(ex.statusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
            assertThat(ex.reason()).isEqualTo("Төлбөрийн систем хараахан холбогдоогүй байна");
            verify(campaigns, never()).tryMarkPaid(anyLong(), any());
            verify(payments, never()).saveAndFlush(any());
        }

        @Test
        void paymentReferenceUsesTheUlaanbaatarCalendarDate() {
            // 20:00 UTC on the 28th is already 04:00 on the 29th in Ulaanbaatar (UTC+8).
            OffsetDateTime at = OffsetDateTime.of(2026, 9, 28, 20, 0, 0, 0, ZoneOffset.UTC);
            assertThat(PaymentReference.of(42L, at)).isEqualTo("UZ-20260929-42");
            OffsetDateTime morning = OffsetDateTime.of(2026, 9, 28, 1, 0, 0, 0, ZoneOffset.UTC);
            assertThat(PaymentReference.of(7L, morning)).isEqualTo("UZ-20260928-7");
        }
    }

    @Nested
    class Payments {

        private CampaignPaymentEntity payment(long id, long campaignId, double amount, String reference,
                                              OffsetDateTime at) {
            CampaignPaymentEntity p = new CampaignPaymentEntity();
            p.setId(id);
            p.setCampaignId(campaignId);
            p.setCompanyId(500L);
            p.setAmount(amount);
            p.setReference(reference);
            p.setCreatedAt(at);
            p.setPaidAt(at);
            return p;
        }

        @Test
        void listsOnlyTheCallersPaymentsNewestFirstWithCampaignTitles() {
            OffsetDateTime now = OffsetDateTime.now();
            when(payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L)).thenReturn(List.of(
                    payment(2L, 11L, 500_000.0, "UZ-20260928-11", now),
                    payment(1L, 10L, 1_000_000.0, "UZ-20260927-10", now.minusDays(1))));
            when(campaigns.findAllById(List.of(11L, 10L)))
                    .thenReturn(List.of(sampleCampaign(10L), sampleCampaign(11L)));

            List<PaymentDto> list = paymentSvc.list(companyId);

            assertThat(list.stream().map(PaymentDto::id).toList()).containsExactly(2L, 1L);
            assertThat(list.get(0).campaignTitle()).isEqualTo("T11");
            assertThat(list.get(1).campaignTitle()).isEqualTo("T10");
            assertThat(list.get(0).status()).isEqualTo(PaymentStatus.PAID);
            assertThat(list.get(0).provider()).isEqualTo(PaymentProvider.SIMULATED);
            verify(payments, times(1)).findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L);
            verify(payments, never()).findAll();
        }

        @Test
        void emptyWhenTheCompanyHasNeverPaid() {
            when(payments.findAllByCompanyIdOrderByCreatedAtDescIdDesc(500L)).thenReturn(List.of());
            when(campaigns.findAllById(List.of())).thenReturn(List.of());
            assertThat(paymentSvc.list(companyId)).isEmpty();
        }
    }
}
