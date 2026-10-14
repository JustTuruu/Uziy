package mn.uziy.backend.company;

import mn.uziy.backend.media.CampaignImageController.ImageResponse;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** HTTP adapter: a company's own survey cover image (same response shape as the admin's). */
@RestController
@RequestMapping("/company/campaigns/{id}/image")
@PreAuthorize("hasRole('COMPANY')")
public class CompanyCampaignImageController {

    private final CompanyCampaignImageService images;

    public CompanyCampaignImageController(CompanyCampaignImageService images) {
        this.images = images;
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ImageResponse upload(@PathVariable("id") long id, @RequestParam("file") MultipartFile file,
                                @Auth JwtPrincipal principal) {
        return new ImageResponse(images.upload(principal.userId(), id, file));
    }

    @DeleteMapping
    public ImageResponse remove(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        images.remove(principal.userId(), id);
        return new ImageResponse(null);
    }
}
