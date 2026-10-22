package mn.uziy.backend.insights;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import mn.uziy.backend.insights.InsightsDtos.OptionShare;
import mn.uziy.backend.insights.InsightsDtos.SegmentRow;
import mn.uziy.backend.insights.InsightsDtos.Segments;
import org.junit.jupiter.api.Test;

class SegmentsCsvTest {

    private static final Segments SEGMENTS = new Segments(7, "Аль нь?", List.of("Тийм", "Үгүй"), List.of(
            new SegmentRow("Бүгд", "Бүх оролцогч", false, 120L,
                    List.of(new OptionShare("Тийм", 60), new OptionShare("Үгүй", 40))),
            new SegmentRow("Хүйс", "Эрэгтэй", true, null, List.of())));

    @Test
    void opensInExcelWithTheRulesAndMarksHiddenGroups() {
        String csv = SegmentsCsv.write("Сошиал", SEGMENTS);

        assertThat(csv).startsWith(SegmentsCsv.BOM);
        assertThat(csv).contains("\"Хэмжүүр\",\"Бүлэг\",\"Хүн (ойролцоо)\",\"Тийм\",\"Үгүй\"");
        assertThat(csv).contains("\"Бүгд\",\"Бүх оролцогч\",\"120\",\"60%\",\"40%\"");
        assertThat(csv).contains("\"Хүйс\",\"Эрэгтэй\",\"< 50\",\"\",\"\"");
        assertThat(csv).contains("Зөвхөн зөвшөөрсөн хэрэглэгчид");
    }

    @Test
    void quotesAreEscapedAndFormulasNeutralised() {
        assertThat(SegmentsCsv.quote("a\"b")).isEqualTo("\"a\"\"b\"");
        assertThat(SegmentsCsv.quote("=HYPERLINK(1)")).isEqualTo("\"'=HYPERLINK(1)\"");
        assertThat(SegmentsCsv.quote("-5")).isEqualTo("\"'-5\"");
        // Tab and carriage return can also start a formula (audit 2026-10-22).
        assertThat(SegmentsCsv.quote("\t=1+1")).isEqualTo("\"'\t=1+1\"");
        assertThat(SegmentsCsv.quote("\r=1+1")).isEqualTo("\"'\r=1+1\"");
        assertThat(SegmentsCsv.quote("Сайн")).isEqualTo("\"Сайн\"");
    }
}
