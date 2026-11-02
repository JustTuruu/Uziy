package mn.uziy.backend.rejoin;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * The keyed hash (HMAC-SHA256, hex) that stands in for a deleted account's phone number. Keyed, not a plain SHA-256:
 * there are only 10^8 eight-digit numbers, so an unkeyed hash could be reversed by trying them all. Without the
 * server's secret the stored hashes say nothing about the numbers.
 */
@Component
public class PhoneFingerprint {

    static final String ALGORITHM = "HmacSHA256";

    private final SecretKeySpec key;

    public PhoneFingerprint(@Value("${uziy.privacy.phone-hash-secret}") String secret) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("uziy.privacy.phone-hash-secret (PHONE_HASH_SECRET) is not set");
        }
        this.key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), ALGORITHM);
    }

    /** 64 lowercase hex characters; the same phone always gives the same value under the same secret. */
    public String of(String phone) {
        try {
            Mac mac = Mac.getInstance(ALGORITHM);
            mac.init(key);
            return HexFormat.of().formatHex(mac.doFinal(phone.getBytes(StandardCharsets.UTF_8)));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(ALGORITHM + " is not available", e);
        }
    }
}
