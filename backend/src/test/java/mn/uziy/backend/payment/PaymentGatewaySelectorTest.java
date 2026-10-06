package mn.uziy.backend.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.List;
import mn.uziy.backend.common.UnavailableException;
import mn.uziy.backend.company.CompanyMessages;
import org.junit.jupiter.api.Test;

class PaymentGatewaySelectorTest {

    private static PaymentGateway gateway(boolean available) {
        PaymentGateway g = mock(PaymentGateway.class);
        when(g.isAvailable()).thenReturn(available);
        return g;
    }

    @Test
    void firstAvailableGatewayWins() {
        PaymentGateway off = gateway(false);
        PaymentGateway first = gateway(true);
        PaymentGateway second = gateway(true);
        assertThat(new PaymentGatewaySelector(List.of(off, first, second)).select()).isSameAs(first);
    }

    @Test
    void throwsUnavailableWhenNoGatewayIsAvailable() {
        PaymentGatewaySelector selector = new PaymentGatewaySelector(List.of(gateway(false)));
        assertThatThrownBy(selector::select)
                .isInstanceOf(UnavailableException.class)
                .hasMessage(CompanyMessages.PAYMENTS_UNAVAILABLE_MESSAGE);
    }

    @Test
    void throwsUnavailableWhenNoGatewaysAreRegistered() {
        assertThatThrownBy(() -> new PaymentGatewaySelector(List.of()).select())
                .isInstanceOf(UnavailableException.class);
    }
}
