package mn.uziy.backend.domain;

/** SIMULATED = the test "Төлөх" button; QPAY / BANK_TRANSFER are reserved for real gateways. */
public enum PaymentProvider {
    SIMULATED, QPAY, BANK_TRANSFER
}
