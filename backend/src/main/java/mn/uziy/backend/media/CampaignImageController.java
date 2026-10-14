package mn.uziy.backend.media;

import org.jspecify.annotations.Nullable;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
public class CampaignImageController {
    private final CampaignImageService images;
    public CampaignImageController(CampaignImageService images) { this.images = images; }
    public record ImageResponse(@Nullable String thumbnailUrl) {}

    @PostMapping(value = "/admin/campaigns/{id}/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('ADMIN')")
    public ImageResponse upload(@PathVariable long id, @RequestParam("file") MultipartFile file) {
        return new ImageResponse(images.upload(id, file));
    }
    @DeleteMapping("/admin/campaigns/{id}/image")
    @PreAuthorize("hasRole('ADMIN')")
    public ImageResponse remove(@PathVariable long id) {
        images.remove(id);
        return new ImageResponse(null);
    }
    @GetMapping("/public/campaigns/{id}/image")
    public ResponseEntity<byte[]> image(@PathVariable long id) {
        var image = images.get(id);
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(image.contentType()))
                .cacheControl(CacheControl.noCache()).header("X-Content-Type-Options", "nosniff")
                .body(image.content());
    }
}
