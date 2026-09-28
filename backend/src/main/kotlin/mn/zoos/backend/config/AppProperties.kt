package mn.zoos.backend.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "zoos")
data class AppProperties(
    val jwt: Jwt = Jwt(),
    val reward: Reward = Reward(),
    val cors: Cors = Cors(),
) {
    data class Jwt(val secret: String = "", val ttlHours: Long = 24)
    data class Reward(val commissionRate: Double = 0.35)
    data class Cors(val allowedOrigins: List<String> = emptyList())
}
