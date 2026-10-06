package mn.uziy.backend.notification;

import java.time.LocalDate;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

/** Pattern: Repository — device tokens plus the audience query for campaign pushes. */
@Repository
public interface DeviceTokenRepository extends JpaRepository<DeviceTokenEntity, Long> {

    Optional<DeviceTokenEntity> findByToken(String token);

    @Transactional
    @Modifying
    @Query("DELETE FROM DeviceTokenEntity d WHERE d.userId = :userId AND d.token = :token")
    int deleteByUserIdAndToken(@Param("userId") long userId, @Param("token") String token);

    /** Removes tokens FCM reported as dead. */
    @Transactional
    @Modifying
    @Query("DELETE FROM DeviceTokenEntity d WHERE d.token IN :tokens")
    int deleteAllByTokenIn(@Param("tokens") Collection<String> tokens);

    /**
     * Tokens of VIEWERs a campaign targets — the same rules as the home feed
     * (CampaignRepository.findFeedFor), minus budget: gender ALL or equal, born within
     * ({@code bornAfter}, {@code bornOnOrBefore}] (= age within [minAge, maxAge], computed by
     * the caller from its Clock), city ALL or equal, and not already completed
     * (no view_history row for the campaign). Native because the targeting values are
     * strings that the caller passes as-is.
     */
    @Query(value = """
        SELECT d.token
          FROM device_tokens d
          JOIN users u ON u.id = d.user_id
         WHERE u.role = 'VIEWER'
           AND (:targetGender = 'ALL' OR u.gender = :targetGender)
           AND u.birth_date > :bornAfter
           AND u.birth_date <= :bornOnOrBefore
           AND (:targetCity = 'ALL' OR u.city = :targetCity)
           AND NOT EXISTS (
               SELECT 1 FROM view_history v
                WHERE v.user_id = u.id AND v.campaign_id = :campaignId)
         ORDER BY d.id
        """, nativeQuery = true)
    List<String> findTokensForCampaign(
            @Param("campaignId") long campaignId,
            @Param("targetGender") String targetGender,
            @Param("targetCity") String targetCity,
            @Param("bornAfter") LocalDate bornAfter,
            @Param("bornOnOrBefore") LocalDate bornOnOrBefore);
}
