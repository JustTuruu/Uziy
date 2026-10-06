package mn.uziy.backend.tools;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.regex.Pattern;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Shared helpers used by two tiny CLI entry points ({@link HashCli}, {@link MakeAdminCli}),
 * each wired to its own Gradle JavaExec task. Kept intentionally free of
 * Spring — {@code makeAdmin} runs BEFORE the dev-seed data exists, so we can't
 * rely on the full app context being up.
 */
public final class Bootstrap {

    private static final Pattern PHONE = Pattern.compile("\\d{8}");
    private static final int MIN_PASSWORD_LENGTH = 6;

    private static final String UPSERT_ADMIN_SQL = """
            INSERT INTO users
              (phone_number, password_hash, role, is_verified, created_at)
            VALUES (?, ?, 'ADMIN', TRUE, ?)
            ON CONFLICT (phone_number) DO UPDATE
              SET role          = 'ADMIN',
                  password_hash = EXCLUDED.password_hash,
                  is_verified   = TRUE
            RETURNING id""";

    private Bootstrap() {
    }

    public static String bcrypt(String password) {
        if (password.isEmpty()) {
            throw new IllegalArgumentException("password must not be empty");
        }
        return new BCryptPasswordEncoder().encode(password);
    }

    /** Same as the 5-arg overload, reading the connection settings from the environment. */
    public static long makeAdmin(String phoneNumber, String password) {
        return makeAdmin(phoneNumber, password,
                envOrDefault("DB_URL", "jdbc:postgresql://localhost:5432/uziy"),
                envOrDefault("DB_USER", "uziy"),
                envOrDefault("DB_PASSWORD", "uziy_dev"));
    }

    /**
     * Insert (or promote) an ADMIN user. Uses {@code ON CONFLICT (phone_number)} so
     * running twice for the same phone just resets the password + role.
     */
    public static long makeAdmin(String phoneNumber, String password,
                                 String dbUrl, String dbUser, String dbPass) {
        if (!PHONE.matcher(phoneNumber).matches()) {
            throw new IllegalArgumentException("phone must be 8 digits");
        }
        if (password.length() < MIN_PASSWORD_LENGTH) {
            throw new IllegalArgumentException("password must be at least 6 chars");
        }

        String hash = bcrypt(password);
        OffsetDateTime now = OffsetDateTime.now();

        try (Connection conn = DriverManager.getConnection(dbUrl, dbUser, dbPass);
             PreparedStatement ps = conn.prepareStatement(UPSERT_ADMIN_SQL)) {
            ps.setString(1, phoneNumber);
            ps.setString(2, hash);
            ps.setObject(3, now);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getLong(1);
                }
                throw new IllegalStateException("upsert returned no row");
            }
        } catch (SQLException e) {
            throw new IllegalStateException(e);
        }
    }

    private static String envOrDefault(String name, String fallback) {
        String v = System.getenv(name);
        return v != null ? v : fallback;
    }
}
