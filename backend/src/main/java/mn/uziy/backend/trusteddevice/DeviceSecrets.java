package mn.uziy.backend.trusteddevice;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.stereotype.Component;

/**
 * The secret a trusted browser keeps, and the only form of it the server stores. The secret is
 * {@value #SECRET_BYTES} random bytes (URL-safe base64, no padding), so it cannot be guessed and its plain SHA-256
 * is a safe lookup key — no salt or slow hash is needed for a value that was never chosen by a person.
 */
@Component
public class DeviceSecrets {

    public static final int SECRET_BYTES = 32;
    /** A secret is 43 characters; anything far longer is not one of ours and is not even hashed. */
    public static final int MAX_SECRET_LENGTH = 128;
    private static final String HASH_ALGORITHM = "SHA-256";

    private final SecureRandom random = new SecureRandom();

    public String next() {
        byte[] bytes = new byte[SECRET_BYTES];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /** Lower-case hex SHA-256 of {@code secret} (64 characters). */
    public static String hash(String secret) {
        try {
            byte[] digest = MessageDigest.getInstance(HASH_ALGORITHM).digest(secret.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("every JVM provides " + HASH_ALGORITHM, e);
        }
    }
}
