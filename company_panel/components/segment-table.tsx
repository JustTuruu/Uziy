import { genderLabel, segmentTint, share } from "@/lib/analytics";
import type { SegmentBreakdown } from "@/lib/api";
import { formatNumber } from "@/lib/utils";

/**
 * Who chose what: one row per answer option, one column per segment (men,
 * women, age bands), each cell the share of that segment's answerers who
 * picked the option. The tint follows the share, and the number is always
 * written, so colour only reinforces. Segments too small to stay anonymous
 * never reach this table (the backend leaves them out).
 */
export function SegmentTable({ breakdown }: { breakdown: SegmentBreakdown }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[420px] text-sm" aria-label={breakdown.prompt}>
        <thead>
          <tr className="text-left text-xs text-[var(--color-text-muted)]">
            <th className="py-2 pr-3 font-semibold">Сонголт</th>
            {breakdown.segments.map((s) => (
              <th key={s.label} className="px-2 py-2 text-center font-semibold">
                <div>{genderLabel(s.label)}</div>
                <div className="font-normal">({formatNumber(s.count)})</div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {breakdown.options.map((option) => (
            <tr key={option.label} className="border-t border-[var(--color-divider)]">
              <th scope="row" className="py-2 pr-3 text-left font-normal text-[var(--color-text-primary)]">
                {option.label}
              </th>
              {option.counts.map((count, i) => {
                const percent = share(count, breakdown.segments[i].count);
                return (
                  <td key={breakdown.segments[i].label} className="p-1">
                    <div
                      className="rounded-md px-2 py-2 text-center font-mono tabular-nums text-[var(--color-text-primary)]"
                      style={{
                        backgroundColor: `color-mix(in oklab, var(--color-primary) ${segmentTint(percent)}%, transparent)`,
                      }}
                    >
                      {percent}%
                    </div>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
