package mn.uziy.backend.domain

import jakarta.persistence.*
import org.springframework.data.jpa.repository.JpaRepository
import java.time.OffsetDateTime

/**
 * Single-row config table. Enforced via a CHECK constraint that `id = 1`
 * (see V4__survey_only_campaigns.sql). Always load with `findById(1L)`.
 *
 * Since V5 it holds the commission model used by
 * [mn.uziy.backend.pricing.CampaignPricing] for BOTH video and survey-only
 * campaigns: the platform keeps `commissionPercent` of every viewer's cost,
 * and a viewer's reward may never drop below `minRewardPerViewer`.
 */
@Entity
@Table(name = "platform_settings")
class PlatformSettingsEntity(
    @Id
    var id: Int = 1,

    /** Platform cut, whole percent, 1..90 (DB CHECK). */
    @Column(name = "commission_percent", nullable = false)
    var commissionPercent: Int = 30,

    /** Floor for a single viewer's reward, whole ₮, >= 1 (DB CHECK). */
    @Column(name = "min_reward_per_viewer", nullable = false)
    var minRewardPerViewer: Int = 100,

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
