package mn.uziy.backend.payment;

import mn.uziy.backend.config.AppProperties;
import mn.uziy.backend.domain.PaymentProvider;
import org.springframework.stereotype.Component;

/**
 * Dev/test gateway: no money moves, the charge "succeeds" instantly. Only
 * available when {@code uziy.payments.simulated} is true (defaults to false so a
 * missing property can never hand out free campaigns).
 */
@Component
public class SimulatedPaymentGateway implements PaymentGateway {

    private final AppProperties props;

    public SimulatedPaymentGateway(AppProperties props) {
        this.props = props;
    }

    @Override
    public PaymentProvider getProvider() {
        return PaymentProvider.SIMULATED;
    }

    @Override
    public boolean isAvailable() {
        return props.payments().simulated();
    }

    @Override
    public ChargeResult charge(ChargeRequest request) {
        return new ChargeResult(PaymentReference.of(request.campaignId(), request.at()));
    }
}
