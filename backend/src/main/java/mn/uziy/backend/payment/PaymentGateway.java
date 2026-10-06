package mn.uziy.backend.payment;

import mn.uziy.backend.domain.PaymentProvider;

/**
 * A way to take a company's money. The payment use case depends only on this
 * interface: supporting a new provider (QPay, bank transfer…) means adding
 * one implementation — no existing code changes.
 */
public interface PaymentGateway {

    PaymentProvider getProvider();

    /** False while the gateway is not configured / switched on. */
    boolean isAvailable();

    /** Takes the money, or throws if it could not. */
    ChargeResult charge(ChargeRequest request);
}
