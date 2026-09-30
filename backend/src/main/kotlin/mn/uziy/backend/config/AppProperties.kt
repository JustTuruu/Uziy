package mn.uziy.backend.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "uziy")
data class AppProperties(
    val jwt: Jwt = Jwt(),
    val cors: Cors = Cors(),
    val payments: Payments = Payments(),
) {
    data class Jwt(val secret: String = "", val ttlHours: Long = 24)
    data class Cors(val allowedOrigins: List<String> = emptyList())

    /**
     * `simulated = true` → POST /company/campaigns/{id}/pay marks the
     * campaign paid instantly (test "Төлөх" button). `false` → the endpoint
     * answers 503 until a real gateway (QPay) is wired. Defaults to false in
     * code so a missing property can never hand out free campaigns;
     * application.yml turns it on for dev via PAYMENTS_SIMULATED.
     */
    data class Payments(val simulated: Boolean = false)
}
