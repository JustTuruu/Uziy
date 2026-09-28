package mn.uziy.backend.domain

import jakarta.persistence.*
import org.springframework.data.jpa.repository.JpaRepository
import java.time.OffsetDateTime

/**
 * Single-row config table. Enforced via a CHECK constraint that `id = 1`
 * (see V4__survey_only_campaigns.sql). Always load with `findById(1L)`.
 */
@Entity
@Table(name = "platform_settings")
class PlatformSettingsEntity(
    @Id
    var id: Int = 1,

    @Column(name = "survey_only_cost_per_response", nullable = false)
    var surveyOnlyCostPerResponse: Double = 400.0,

    @Column(name = "survey_only_reward_per_user", nullable = false)
    var surveyOnlyRewardPerUser: Double = 250.0,

    @Column(name = "updated_at", nullable = false)
    var updatedAt: OffsetDateTime = OffsetDateTime.now(),

    @Column(name = "updated_by")
    var updatedBy: Long? = null,
)

interface PlatformSettingsRepository : JpaRepository<PlatformSettingsEntity, Int>

/**
 * Load the singleton config row. Extracted from the repository so it can be
 * mocked with MockK — default methods on JPA interfaces are intercepted by
 * Spring's proxy before the default body ever runs.
 */
fun PlatformSettingsRepository.current(): PlatformSettingsEntity =
    findById(1).orElseThrow { IllegalStateException("platform_settings row missing") }
