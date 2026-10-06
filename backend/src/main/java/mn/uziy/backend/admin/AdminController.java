package mn.uziy.backend.admin;

import java.util.List;
import mn.uziy.backend.company.CampaignDto;
import mn.uziy.backend.domain.CampaignStatus;
import org.jspecify.annotations.Nullable;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for the super admin console. */
@RestController
@RequestMapping("/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final AdminStatsService stats;
    private final UserAdminService users;
    private final CampaignModerationService moderation;

    public AdminController(AdminStatsService stats, UserAdminService users, CampaignModerationService moderation) {
        this.stats = stats;
        this.users = users;
        this.moderation = moderation;
    }

    @GetMapping("/stats")
    public AdminStats stats() {
        return stats.stats();
    }

    @GetMapping("/users")
    public List<UserDto> listUsers() {
        return users.list();
    }

    @GetMapping("/users/{id}")
    public UserDto getUser(@PathVariable("id") long id) {
        return users.get(id);
    }

    @PatchMapping("/users/{id}/verify")
    public UserDto verify(@PathVariable("id") long id) {
        return users.verify(id);
    }

    @GetMapping("/campaigns")
    public List<CampaignDto> listCampaigns(
            @RequestParam(name = "status", required = false) @Nullable CampaignStatus status,
            @RequestParam(name = "companyId", required = false) @Nullable Long companyId) {
        return moderation.list(status, companyId);
    }

    @GetMapping("/campaigns/{id}")
    public CampaignDetailDto getCampaign(@PathVariable("id") long id) {
        return moderation.get(id);
    }

    @PatchMapping("/campaigns/{id}/moderate")
    public CampaignDto moderate(@PathVariable("id") long id, @RequestParam("decision") CampaignStatus decision) {
        return moderation.moderate(id, decision);
    }
}
