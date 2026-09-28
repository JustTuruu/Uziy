package mn.uziy.backend.tools

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import java.sql.DriverManager
import java.time.OffsetDateTime
import kotlin.system.exitProcess

/**
 * Shared helpers used by two tiny CLI entry points (HashCli, MakeAdminCli),
 * each wired to its own Gradle JavaExec task. Kept intentionally free of
 * Spring — `makeAdmin` runs BEFORE the dev-seed data exists, so we can't
 * rely on the full app context being up.
 */

fun bcrypt(password: String): String {
    require(password.isNotEmpty()) { "password must not be empty" }
    return BCryptPasswordEncoder().encode(password)!!
}

/**
 * Insert (or promote) an ADMIN user. Uses `ON CONFLICT (phone_number)` so
 * running twice for the same phone just resets the password + role.
 */
fun makeAdmin(
    phoneNumber: String,
    password: String,
    dbUrl: String  = System.getenv("DB_URL")      ?: "jdbc:postgresql://localhost:5432/uziy",
    dbUser: String = System.getenv("DB_USER")     ?: "uziy",
    dbPass: String = System.getenv("DB_PASSWORD") ?: "uziy_dev",
): Long {
    require(phoneNumber.matches(Regex("\\d{8}"))) { "phone must be 8 digits" }
    require(password.length >= 6) { "password must be at least 6 chars" }

    val hash = bcrypt(password)
    val now = OffsetDateTime.now()

    DriverManager.getConnection(dbUrl, dbUser, dbPass).use { conn ->
        conn.prepareStatement("""
            INSERT INTO users
              (phone_number, password_hash, role, is_verified, created_at)
            VALUES (?, ?, 'ADMIN', TRUE, ?)
            ON CONFLICT (phone_number) DO UPDATE
              SET role          = 'ADMIN',
                  password_hash = EXCLUDED.password_hash,
                  is_verified   = TRUE
            RETURNING id
        """.trimIndent()).use { ps ->
            ps.setString(1, phoneNumber)
            ps.setString(2, hash)
            ps.setObject(3, now)
            ps.executeQuery().use { rs ->
                if (rs.next()) return rs.getLong(1)
                throw IllegalStateException("upsert returned no row")
            }
        }
    }
}

object HashCli {
    @JvmStatic
    fun main(args: Array<String>) {
        if (args.size != 1) {
            System.err.println("usage: hash <password>")
            exitProcess(64)
        }
        println(bcrypt(args[0]))
    }
}

object MakeAdminCli {
    @JvmStatic
    fun main(args: Array<String>) {
        if (args.size != 2) {
            System.err.println("usage: makeAdmin <phone8digits> <password>")
            exitProcess(64)
        }
        val id = makeAdmin(args[0], args[1])
        println("ok: admin id=$id phone=${args[0]}")
    }
}
