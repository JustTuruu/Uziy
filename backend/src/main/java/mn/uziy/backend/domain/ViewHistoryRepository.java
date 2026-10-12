package mn.uziy.backend.domain;

import java.util.List;
import org.springframework.data.domain.Pageable;
import java.time.OffsetDateTime;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/** Completed views; (user, campaign) is unique, which blocks double rewards. */
@Repository
public interface ViewHistoryRepository extends JpaRepository<ViewHistoryEntity, Long> {
    boolean existsByUserIdAndCampaignId(long userId, long campaignId);

    long countByCampaignId(long campaignId);

    /** A viewer's most recent completed views, newest first; the caller bounds the size with {@code limit}. */
    List<ViewHistoryEntity> findByUserIdOrderByWatchedAtDesc(long userId, Pageable limit);

    /** Views and paid rewards per campaign for every campaign of one company (campaigns nobody watched are absent). */
    @Query("""
        SELECT new mn.uziy.backend.domain.CampaignViewStats(v.campaignId, COUNT(v), COALESCE(SUM(v.rewardPaid), 0.0))
        FROM ViewHistoryEntity v
        WHERE v.campaignId IN (SELECT c.id FROM CampaignEntity c WHERE c.companyId = :companyId)
        GROUP BY v.campaignId
    """)
    List<CampaignViewStats> statsByCompany(@Param("companyId") long companyId);

    /**
     * Completed views per calendar day (in {@code zone}) since {@code since}, as rows of
     * [{@link java.sql.Date} day, {@link Long} count]. {@code campaignId} null means all of the company's campaigns.
     */
    @Query(value = """
        SELECT CAST(timezone(:zone, v.watched_at) AS date) AS day, COUNT(*) AS n
        FROM view_history v JOIN campaigns c ON c.id = v.campaign_id
        WHERE c.company_id = :companyId
          AND (CAST(:campaignId AS bigint) IS NULL OR c.id = :campaignId)
          AND v.watched_at >= :since
        GROUP BY day ORDER BY day
    """, nativeQuery = true)
    List<Object[]> dailyCounts(@Param("companyId") long companyId, @Param("campaignId") Long campaignId,
                               @Param("since") OffsetDateTime since, @Param("zone") String zone);

    /** Viewers who completed the company's campaign(s), counted per gender: rows of [gender text, count]. */
    @Query(value = """
        SELECT CAST(u.gender AS text), COUNT(*)
        FROM view_history v JOIN campaigns c ON c.id = v.campaign_id JOIN users u ON u.id = v.user_id
        WHERE c.company_id = :companyId AND (CAST(:campaignId AS bigint) IS NULL OR c.id = :campaignId)
          AND u.gender IS NOT NULL
        GROUP BY u.gender
    """, nativeQuery = true)
    List<Object[]> genderCounts(@Param("companyId") long companyId, @Param("campaignId") Long campaignId);

    /** Same viewers counted per age in whole years: rows of [age, count]. */
    @Query(value = """
        SELECT CAST(date_part('year', age(u.birth_date)) AS int), COUNT(*)
        FROM view_history v JOIN campaigns c ON c.id = v.campaign_id JOIN users u ON u.id = v.user_id
        WHERE c.company_id = :companyId AND (CAST(:campaignId AS bigint) IS NULL OR c.id = :campaignId)
          AND u.birth_date IS NOT NULL
        GROUP BY 1
    """, nativeQuery = true)
    List<Object[]> ageCounts(@Param("companyId") long companyId, @Param("campaignId") Long campaignId);

    /** Same viewers counted per city, biggest first: rows of [city, count]. */
    @Query(value = """
        SELECT u.city, COUNT(*)
        FROM view_history v JOIN campaigns c ON c.id = v.campaign_id JOIN users u ON u.id = v.user_id
        WHERE c.company_id = :companyId AND (CAST(:campaignId AS bigint) IS NULL OR c.id = :campaignId)
          AND u.city IS NOT NULL
        GROUP BY u.city ORDER BY COUNT(*) DESC, u.city
    """, nativeQuery = true)
    List<Object[]> cityCounts(@Param("companyId") long companyId, @Param("campaignId") Long campaignId);

    /** Views per campaign since {@code since} (campaigns with none are absent): the recent pace. */
    @Query("""
        SELECT new mn.uziy.backend.domain.CampaignRecentViews(v.campaignId, COUNT(v))
        FROM ViewHistoryEntity v
        WHERE v.watchedAt >= :since
          AND v.campaignId IN (SELECT c.id FROM CampaignEntity c WHERE c.companyId = :companyId)
        GROUP BY v.campaignId
    """)
    List<CampaignRecentViews> recentByCompany(@Param("companyId") long companyId,
                                              @Param("since") OffsetDateTime since);

    /** Completed views per hour of the day (0..23, in {@code zone}) since {@code since}: rows of [hour, count]. */
    @Query(value = """
        SELECT CAST(date_part('hour', timezone(:zone, v.watched_at)) AS int) AS hour, COUNT(*)
        FROM view_history v JOIN campaigns c ON c.id = v.campaign_id
        WHERE c.company_id = :companyId
          AND (CAST(:campaignId AS bigint) IS NULL OR c.id = :campaignId)
          AND v.watched_at >= :since
        GROUP BY hour ORDER BY hour
    """, nativeQuery = true)
    List<Object[]> hourlyCounts(@Param("companyId") long companyId, @Param("campaignId") Long campaignId,
                                @Param("since") OffsetDateTime since, @Param("zone") String zone);
}
