package mn.uziy.backend.payment;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.PaymentProvider;
import org.junit.jupiter.api.Test;

class PaymentGatewayTest {

    private final OffsetDateTime at = OffsetDateTime.of(2026, 9, 29, 10, 0, 0, 0, ZoneOffset.UTC);

    private SimulatedPaymentGateway simulated(boolean on) {
        return new SimulatedPaymentGateway(
                new AppProperties(new AppProperties.Jwt("", 24), new AppProperties.Cors(List.of()),
                        new AppProperties.Payments(on),
            new AppProperties.Push(false, "")));
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
}
