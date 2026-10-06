package mn.uziy.backend.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import mn.uziy.backend.common.UnavailableException;
import mn.uziy.backend.company.CampaignPaymentServiceImpl;
import mn.uziy.backend.company.CompanyMessages;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignPaymentEntity;
import mn.uziy.backend.domain.CampaignPaymentRepository;
import mn.uziy.backend.domain.CampaignRepository;
import mn.uziy.backend.domain.CampaignStatus;
import mn.uziy.backend.domain.PaymentProvider;
import mn.uziy.backend.domain.TargetGender;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PaymentGatewayTest {

    private final OffsetDateTime at = OffsetDateTime.of(2026, 9, 29, 10, 0, 0, 0, ZoneOffset.UTC);

    private SimulatedPaymentGateway simulated(boolean on) {
        return new SimulatedPaymentGateway(
                new AppProperties(new AppProperties.Jwt("", 24), new AppProperties.Cors(List.of()),
                        new AppProperties.Payments(on)));
    }

    @Test
    void simulated_gateway_is_available_only_when_switched_on() {
        assertThat(simulated(true).isAvailable()).isTrue();
        assertThat(simulated(false).isAvailable()).isFalse();
    }

    @Test
    void simulated_gateway_reports_the_SIMULATED_provider_and_an_invoice_reference() {
        SimulatedPaymentGateway g = simulated(true);
        assertThat(g.getProvider()).isEqualTo(PaymentProvider.SIMULATED);
        assertThat(g.charge(new ChargeRequest(42L, 500L, 1_000.0, at)).reference())
                .isEqualTo("UZ-20260929-42");
    }

    // --- the payment use case only knows the PaymentGateway interface ---------

    private final CampaignRepository campaigns = mock(CampaignRepository.class);
    private final CampaignPaymentRepository payments = mock(CampaignPaymentRepository.class);

    private CampaignEntity awaiting() {
        CampaignEntity c = new CampaignEntity();
        c.setId(42L);
        c.setCompanyId(500L);
        c.setTitle("T");
        c.setDurationSeconds(30);
        c.setTargetGender(TargetGender.ALL);
        c.setMinAge(18);
        c.setMaxAge(45);
        c.setTargetCity("ALL");
        c.setTotalBudget(1_000_000.0);
        c.setRemainingBudget(1_000_000.0);
        c.setCostPerView(1_000.0);
        c.setRewardPerUser(700.0);
        c.setStatus(CampaignStatus.AWAITING_PAYMENT);
        return c;
    }

    private static final class FakeGateway implements PaymentGateway {
        private final PaymentProvider provider;
        private final boolean available;
        int charged = 0;

        FakeGateway(PaymentProvider provider, boolean available) {
            this.provider = provider;
            this.available = available;
        }

        @Override
        public PaymentProvider getProvider() {
            return provider;
        }

        @Override
        public boolean isAvailable() {
            return available;
        }

        @Override
        public ChargeResult charge(ChargeRequest request) {
            charged++;
            return new ChargeResult("FAKE-" + request.campaignId());
        }
    }

    @Test
    void a_new_provider_works_without_touching_the_payment_service_first_available_gateway_wins() {
        FakeGateway off = new FakeGateway(PaymentProvider.QPAY, false);
        FakeGateway on = new FakeGateway(PaymentProvider.BANK_TRANSFER, true);
        when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting()));
        when(campaigns.tryMarkPaid(org.mockito.ArgumentMatchers.eq(42L), any())).thenReturn(1);
        ArgumentCaptor<CampaignPaymentEntity> saved = ArgumentCaptor.forClass(CampaignPaymentEntity.class);
        when(payments.saveAndFlush(saved.capture())).thenAnswer(inv -> {
            CampaignPaymentEntity p = inv.getArgument(0);
            p.setId(7L);
            return p;
        });

        var res = new CampaignPaymentServiceImpl(campaigns, payments, List.of(off, on)).pay(500L, 42L);

        assertThat(off.charged).isEqualTo(0);
        assertThat(on.charged).isEqualTo(1);
        assertThat(saved.getValue().getProvider()).isEqualTo(PaymentProvider.BANK_TRANSFER);
        assertThat(res.payment().reference()).isEqualTo("FAKE-42");
    }

    @Test
    void no_available_gateway_answers_unavailable_and_marks_nothing_paid() {
        when(campaigns.findById(42L)).thenReturn(Optional.of(awaiting()));

        var service = new CampaignPaymentServiceImpl(campaigns, payments,
                List.of(new FakeGateway(PaymentProvider.QPAY, false)));
        assertThatThrownBy(() -> service.pay(500L, 42L))
                .isInstanceOf(UnavailableException.class)
                .hasMessage(CompanyMessages.PAYMENTS_UNAVAILABLE_MESSAGE);
    }
}
