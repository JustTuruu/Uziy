package mn.uziy.backend.payment;

import java.util.List;
import mn.uziy.backend.common.UnavailableException;
import org.springframework.stereotype.Component;

/**
 * Pattern: Registry/Factory — picks the first available {@link PaymentGateway}
 * among all registered ones, so a new provider is just a new @Component.
 */
@Component
public class PaymentGatewaySelector {

    /** Shown when no gateway is available (503). */
    public static final String UNAVAILABLE_MESSAGE = "Төлбөрийн систем хараахан холбогдоогүй байна";

    private final List<PaymentGateway> gateways;

    public PaymentGatewaySelector(List<PaymentGateway> gateways) {
        this.gateways = gateways;
    }

    /** First gateway whose {@code isAvailable()} is true, else {@link UnavailableException}. */
    public PaymentGateway select() {
        return gateways.stream()
                .filter(PaymentGateway::isAvailable)
                .findFirst()
                .orElseThrow(() -> new UnavailableException(UNAVAILABLE_MESSAGE));
    }
}
