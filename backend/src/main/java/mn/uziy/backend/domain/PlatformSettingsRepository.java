package mn.uziy.backend.domain;

import org.springframework.data.jpa.repository.JpaRepository;

/** Repository for the single-row platform_settings table; load the row via {@link PlatformSettings#current}. */
public interface PlatformSettingsRepository extends JpaRepository<PlatformSettingsEntity, Integer> {
}
