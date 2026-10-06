package mn.uziy.backend.settings;

public interface PlatformSettingsService {

    PlatformSettingsDto get();

    /**
     * Only affects campaigns created from now on — existing campaigns keep
     * the reward/cost (and commission snapshot) they were priced with.
     */
    PlatformSettingsDto update(UpdatePlatformSettingsReq req, long adminId);
}
