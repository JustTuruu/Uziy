package mn.uziy.backend.insights;

import java.nio.charset.StandardCharsets;
import java.util.List;
import mn.uziy.backend.insights.InsightsDtos.AccessLogEntry;
import mn.uziy.backend.insights.InsightsDtos.Distribution;
import mn.uziy.backend.insights.InsightsDtos.Filter;
import mn.uziy.backend.insights.InsightsDtos.Overview;
import mn.uziy.backend.insights.InsightsDtos.QuestionSummary;
import mn.uziy.backend.insights.InsightsDtos.Segments;
import mn.uziy.backend.security.Auth;
import mn.uziy.backend.security.JwtPrincipal;
import org.jspecify.annotations.Nullable;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** HTTP adapter for the super admin's anonymous statistics (ADMIN only). */
@RestController
@RequestMapping("/admin/insights")
@PreAuthorize("hasRole('ADMIN')")
public class InsightsController {

    private final InsightsService insights;

    public InsightsController(InsightsService insights) {
        this.insights = insights;
    }

    @GetMapping("/overview")
    public Overview overview(@Auth JwtPrincipal principal) {
        return insights.overview(principal.userId());
    }

    @GetMapping("/questions")
    public List<QuestionSummary> questions(@Auth JwtPrincipal principal) {
        return insights.questions(principal.userId());
    }

    @GetMapping("/questions/{id}")
    public Distribution distribution(
            @PathVariable("id") long id,
            @RequestParam(name = "gender", required = false) @Nullable String gender,
            @RequestParam(name = "ageBand", required = false) @Nullable String ageBand,
            @RequestParam(name = "city", required = false) @Nullable String city,
            @Auth JwtPrincipal principal) {
        return insights.distribution(principal.userId(), id, new Filter(gender, ageBand, city));
    }

    @GetMapping("/questions/{id}/segments")
    public Segments segments(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        return insights.segments(principal.userId(), id);
    }

    @GetMapping("/questions/{id}/export.csv")
    public ResponseEntity<byte[]> export(@PathVariable("id") long id, @Auth JwtPrincipal principal) {
        byte[] csv = insights.exportCsv(principal.userId(), id).getBytes(StandardCharsets.UTF_8);
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "csv", StandardCharsets.UTF_8))
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename("uziy-statistic-" + id + ".csv").build().toString())
                .body(csv);
    }

    @GetMapping("/access-log")
    public List<AccessLogEntry> accessLog(@Auth JwtPrincipal principal) {
        return insights.accessLog(principal.userId());
    }
}
