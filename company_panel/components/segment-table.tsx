import { segmentTint } from "@/lib/analytics";
import type { SegmentGrid } from "@/lib/survey-results";
import { formatNumber } from "@/lib/utils";

/** The tints shown in the legend, so a reader knows what "darker" means. */
const LEGEND_STEPS = [0, 25, 50, 75, 100] as const;

const cellStyle = (percent: number) => ({
  backgroundColor: `color-mix(in oklab, var(--color-primary) ${segmentTint(percent)}%, transparent)`,
});

/**
 * Who chose what: one row per answer, columns grouped as Хүйс (men, women) and Нас (age bands), each cell the
 * share of that group's answerers who picked the answer. The number is always written; the tint only reinforces
 * it. Groups too small to stay anonymous never reach this table (the backend leaves them out).
 */
export function SegmentTable({ grid, caption }: { grid: SegmentGrid; caption: string }) {
  const groupStarts = new Set<number>();
  let offset = 0;
  for (const g of grid.groups) {
    groupStarts.add(offset);
    offset += g.columns.length;
  }
  const columns = grid.groups.flatMap((g) => g.columns);
  const divider = (index: number) =>
    index > 0 && groupStarts.has(index) ? "border-l border-[var(--color-divider)]" : "";

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[420px] border-collapse text-sm">
        <caption className="sr-only">{caption}</caption>
        <thead>
          <tr className="text-2xs uppercase tracking-wider text-[var(--color-text-muted)]">
            <td rowSpan={2} aria-hidden />
            {grid.groups.map((g, i) => (
              <th
                key={g.title}
                scope="colgroup"
                colSpan={g.columns.length}
                className={`px-2 pb-1 text-center font-semibold ${i > 0 ? "border-l border-[var(--color-divider)]" : ""}`}
              >
                {g.title}
              </th>
            ))}
          </tr>
          <tr className="text-xs text-[var(--color-text-secondary)]">
            {columns.map((c, i) => (
              <th key={c.label} scope="col" className={`px-2 pb-2 text-center font-semibold ${divider(i)}`}>
                <div className="text-[var(--color-text-primary)]">{c.label}</div>
                <div className="font-normal text-[var(--color-text-muted)]">{formatNumber(c.size)} хүн</div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {grid.rows.map((row) => (
            <tr key={row.option} className="border-t border-[var(--color-divider)]">
              <th
                scope="row"
                className="max-w-56 py-1.5 pr-3 text-left font-normal text-[var(--color-text-primary)]"
              >
                {row.option}
              </th>
              {row.cells.map((cell, i) => (
                <td key={cell.segment} className={`p-1 ${divider(i)}`}>
                  <div
                    className="rounded-md px-2 py-1.5 text-center font-mono tabular-nums text-[var(--color-text-primary)]"
                    style={cellStyle(cell.percent)}
                    title={`${formatNumber(cell.count)} / ${formatNumber(columns[i].size)} хүн`}
                  >
                    {cell.percent}%
                  </div>
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** The 0 → 100% tint scale, drawn small; the sentence beside it says the same in words. */
export function SegmentTintScale() {
  return (
    <div aria-hidden className="flex items-center gap-1 text-3xs text-[var(--color-text-muted)]">
      <span>0%</span>
      {LEGEND_STEPS.map((p) => (
        <span
          key={p}
          className="h-3 w-5 rounded-sm border border-[var(--color-divider)]"
          style={cellStyle(p)}
        />
      ))}
      <span>100%</span>
    </div>
  );
}
