package mn.zoos.backend.security

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.security.Keys
import mn.zoos.backend.config.AppProperties
import mn.zoos.backend.domain.Role
import mn.zoos.backend.domain.UserEntity
import org.springframework.stereotype.Service
import java.util.Date
import javax.crypto.SecretKey

data class JwtPrincipal(val userId: Long, val role: Role)

@Service
class JwtService(private val props: AppProperties) {

    private val key: SecretKey by lazy {
        Keys.hmacShaKeyFor(props.jwt.secret.toByteArray(Charsets.UTF_8))
    }

    fun issue(user: UserEntity): String {
        val now = Date()
        val exp = Date(now.time + props.jwt.ttlHours * 3600 * 1000)
        return Jwts.builder()
            .subject(user.id.toString())
            .claim("role", user.role.name)
            .issuedAt(now)
            .expiration(exp)
            .signWith(key)
            .compact()
    }

    fun parse(token: String): JwtPrincipal {
        val claims = Jwts.parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .payload
        return JwtPrincipal(
            userId = claims.subject.toLong(),
            role   = Role.valueOf(claims["role", String::class.java]),
        )
    }
}
