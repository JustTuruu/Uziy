package mn.uziy.backend.insights;

import java.util.ArrayList;
import java.util.List;
import mn.uziy.backend.insights.InsightsDtos.OptionShare;
import mn.uziy.backend.insights.InsightsDtos.SegmentRow;
import mn.uziy.backend.insights.InsightsDtos.Segments;

/** Writes segments as CSV for Excel: UTF-8 BOM, quoted cells, suppressed groups marked instead of numbers. */
final class SegmentsCsv {

    static final String BOM = "﻿";
    static final String SUPPRESSED = "< " + StatisticsPrivacyPolicy.MIN_GROUP_SIZE;

    private SegmentsCsv() {
    }

    static String write(String surveyTitle, Segments s) {
        StringBuilder out = new StringBuilder(BOM);
        line(out, List.of("Судалгаа", surveyTitle));
        line(out, List.of("Асуулт", s.prompt()));
        line(out, List.of("Дүрэм", "Зөвхөн зөвшөөрсөн хэрэглэгчид; " + StatisticsPrivacyPolicy.MIN_GROUP_SIZE
                + "-аас цөөн бүлгийг нууцалсан; хүний тоог " + StatisticsPrivacyPolicy.COUNT_STEP
                + "-аар доош бүхэлтгэсэн; хувь"));
        line(out, List.of());
        List<String> header = new ArrayList<>(List.of("Хэмжүүр", "Бүлэг", "Хүн (ойролцоо)"));
        header.addAll(s.options());
        line(out, header);
        for (SegmentRow r : s.rows()) {
            List<String> cells = new ArrayList<>(List.of(r.dimension(), r.label()));
            if (r.suppressed()) {
                cells.add(SUPPRESSED);
                s.options().forEach(o -> cells.add(""));
            } else {
                cells.add(String.valueOf(r.people()));
                for (OptionShare share : r.shares()) {
                    cells.add(share.percent() + "%");
                }
            }
            line(out, cells);
        }
        return out.toString();
    }

    private static void line(StringBuilder out, List<String> cells) {
        out.append(String.join(",", cells.stream().map(SegmentsCsv::quote).toList())).append("\r\n");
    }

    /** Characters a spreadsheet may treat as the start of a formula (OWASP CSV injection list). */
    private static final String FORMULA_STARTS = "=+-@\t\r";

    /** Quotes every cell and neutralises a leading formula character (CSV injection). */
    static String quote(String cell) {
        String safe = !cell.isEmpty() && FORMULA_STARTS.indexOf(cell.charAt(0)) >= 0 ? "'" + cell : cell;
        return "\"" + safe.replace("\"", "\"\"") + "\"";
    }
}
