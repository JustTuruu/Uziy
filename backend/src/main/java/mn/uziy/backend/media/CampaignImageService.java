package mn.uziy.backend.media;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.UUID;
import javax.imageio.ImageIO;
import mn.uziy.backend.common.BadRequestException;
import mn.uziy.backend.common.Messages;
import mn.uziy.backend.common.NotFoundException;
import mn.uziy.backend.domain.CampaignEntity;
import mn.uziy.backend.domain.CampaignRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CampaignImageService {
    public static final long MAX_BYTES = 5 * 1024 * 1024;
    public static final String INVALID = "5 MB хүртэлх JPG эсвэл PNG зураг сонгоно уу";
    private final CampaignRepository campaigns;
    private final CampaignImageRepository images;
    public CampaignImageService(CampaignRepository campaigns, CampaignImageRepository images) {
        this.campaigns = campaigns;
        this.images = images;
    }
    @Transactional
    public String upload(long id, MultipartFile file) {
        campaign(id);
        var image = decode(file);
        images.save(id, image);
        String url = "/public/campaigns/" + id + "/image?v=" + UUID.randomUUID();
        campaigns.updateThumbnail(id, url);
        return url;
    }
    @Transactional
    public void remove(long id) {
        campaign(id);
        images.delete(id);
        campaigns.updateThumbnail(id, null);
    }
    public CampaignImageRepository.Image get(long id) {
        return images.find(id).orElseThrow(() -> new NotFoundException("Зураг олдсонгүй"));
    }
    private CampaignEntity campaign(long id) {
        return campaigns.findById(id).orElseThrow(() -> new NotFoundException(Messages.CAMPAIGN_NOT_FOUND));
    }
    // Decode and re-encode instead of trusting the extension/MIME or keeping embedded metadata.
    static CampaignImageRepository.Image decode(MultipartFile file) {
        if (file.isEmpty() || file.getSize() > MAX_BYTES) throw new BadRequestException(INVALID);
        try (var input = ImageIO.createImageInputStream(file.getInputStream())) {
            var readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) throw new BadRequestException(INVALID);
            var reader = readers.next();
            try {
                reader.setInput(input);
                String format = reader.getFormatName().toLowerCase(java.util.Locale.ROOT);
                if (!format.equals("png") && !format.equals("jpeg") && !format.equals("jpg"))
                    throw new BadRequestException(INVALID);
                long pixels = (long) reader.getWidth(0) * reader.getHeight(0);
                if (pixels > 16_000_000 || pixels < 1)
                    throw new BadRequestException("Зургийн хэмжээ 16 сая пикселээс хэтрэхгүй байна");
                BufferedImage decoded = reader.read(0);
                var output = new ByteArrayOutputStream();
                boolean png = format.equals("png");
                ImageIO.write(decoded, png ? "png" : "jpeg", output);
                if (output.size() > MAX_BYTES) throw new BadRequestException(INVALID);
                return new CampaignImageRepository.Image(output.toByteArray(), png ? "image/png" : "image/jpeg");
            } finally { reader.dispose(); }
        } catch (IOException | IllegalArgumentException e) {
            throw new BadRequestException(INVALID);
        }
    }
}
