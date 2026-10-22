package mn.uziy.backend.analytics;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import mn.uziy.backend.analytics.AnalyticsDtos.Slice;

/**
 * Pattern: Policy object — the one anonymity rule every breakdown in company analytics obeys.
 *
 * <p>A slice of a dimension (a gender, an age band, a city, an answer segment) is shown only when at least
 * {@code min} people are in it. Hiding the small slice is not enough on its own: the company also sees the
 * dimension's total (responses, a question's answer count), so "total − every shown slice" would give the hidden
 * slice back by subtraction. Therefore the people left out must together be either nobody or at least
 * {@code min}; while they are not, the smallest shown slice is hidden as well (complementary suppression).
 * Empty slices stay visible ("nobody" points at no one, and a chart keeps its shape) unless only they would be
 * left beside a small hidden group: then nothing of the dimension is shown.
 */
final class SmallGroupRule {

    private SmallGroupRule() {
    }

    /**
     * @param slices the dimension's slices, in display order
     * @param total  how many people the dimension covers as far as the company can tell; at least the slices' sum
     * @param min    smallest group that may be shown
     * @return the slices that can be shown, in their original order
     */
    static List<Slice> reportable(List<Slice> slices, long total, int min) {
        long all = Math.max(total, slices.stream().mapToLong(Slice::count).sum());
        List<Slice> shown = new ArrayList<>(slices.stream().filter(s -> s.count() == 0 || s.count() >= min).toList());
        long hidden = all - shown.stream().mapToLong(Slice::count).sum();
        while (hidden > 0 && hidden < min) {
            Slice smallest = shown.stream()
                    .filter(s -> s.count() > 0)
                    .min(Comparator.comparingLong(Slice::count))
                    .orElse(null);
            if (smallest == null) {
                // Only empty slices are left, and they would still point at the few hidden people.
                return List.of();
            }
            shown.remove(smallest);
            hidden += smallest.count();
        }
        return shown;
    }
}
