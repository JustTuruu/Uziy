package mn.uziy.backend.admin

import mn.uziy.backend.company.CampaignDto
import mn.uziy.backend.domain.CampaignStatus
import org.springframework.security.access.prepost.PreAuthorize
import org.springframework.web.bind.annotation.*

/** HTTP adapter for the super admin console. */
@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
class AdminController(
    private val stats: AdminStatsService,
    private val users: UserAdminService,
    private val moderation: CampaignModerationService,
) {

    @GetMapping("/stats")
    fun stats(): AdminStats = stats.stats()

    @GetMapping("/users")
    fun listUsers(): List<UserDto> = users.list()

    @GetMapping("/users/{id}")
    fun getUser(@PathVariable id: Long): UserDto = users.get(id)

    @PatchMapping("/users/{id}/verify")
    fun verify(@PathVariable id: Long): UserDto = users.verify(id)

    @GetMapping("/campaigns")
    fun listCampaigns(
        @RequestParam(required = false) status: CampaignStatus?,
        @RequestParam(required = false) companyId: Long?,
    ): List<CampaignDto> = moderation.list(status, companyId)

    @GetMapping("/campaigns/{id}")
    fun getCampaign(@PathVariable id: Long): CampaignDetailDto = moderation.get(id)

    @PatchMapping("/campaigns/{id}/moderate")
    fun moderate(@PathVariable id: Long, @RequestParam decision: CampaignStatus): CampaignDto =
        moderation.moderate(id, decision)
}
