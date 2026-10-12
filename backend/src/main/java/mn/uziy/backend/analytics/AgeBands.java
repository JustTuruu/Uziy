package mn.uziy.backend.analytics;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;

/** Groups ages into the bands advertisers read: 13–17, 18–24, 25–34, 35–44, 45+. */
final class AgeBands {

    private record Band(String label, int min, int max) {
        boolean contains(int age) {
            return age >= min && age <= max;
        }
    }

    private static final List<Band> BANDS = List.of(
            new Band("13–17", 0, 17),
            new Band("18–24", 18, 24),
            new Band("25–34", 25, 34),
            new Band("35–44", 35, 44),
            new Band("45+", 45, Integer.MAX_VALUE));

    private AgeBands() {
    }

    /** Label of the band an age falls in. */
    static String labelOf(int age) {
        for (Band band : BANDS) {
            if (band.contains(age)) {
                return band.label();
            }
        }
        throw new IllegalStateException("No band for age " + age);
    }

    /** Every band, in order, with its total (zero included, so a chart keeps a stable shape). */
    static List<Slice> group(Map<Integer, Long> countsByAge) {
        List<Slice> out = new ArrayList<>();
        for (Band band : BANDS) {
            long total = 0;
            for (Map.Entry<Integer, Long> e : countsByAge.entrySet()) {
                if (band.contains(e.getKey())) {
                    total += e.getValue();
                }
            }
            out.add(new Slice(band.label(), total));
        }
        return out;
    }
}
