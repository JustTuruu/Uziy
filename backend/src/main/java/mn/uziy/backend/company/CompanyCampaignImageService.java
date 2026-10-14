package mn.uziy.backend.company;

import org.springframework.web.multipart.MultipartFile;

/** A company sets or removes the cover image of its own survey, before it is approved. */
public interface CompanyCampaignImageService {

    /**
     * Stores {@code file} as the cover and returns its URL.
     *
     * @throws mn.uziy.backend.common.NotFoundException for an unknown campaign
     * @throws mn.uziy.backend.common.ForbiddenException for another company's campaign
     * @throws mn.uziy.backend.common.ConflictException once the campaign was approved (or rejected / ended)
     * @throws mn.uziy.backend.common.BadRequestException for a file that is not a JPG/PNG up to 5 MB
     */
    String upload(long companyId, long campaignId, MultipartFile file);

    /** Removes the cover; the same rules as {@link #upload}. */
    void remove(long companyId, long campaignId);
}
