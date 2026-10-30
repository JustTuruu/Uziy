import { useState } from "react";
import { axisTicks, labelIndexes, niceCeil } from "@company/lib/analytics";
import { useElementWidth } from "@company/lib/use-element-width";
import { formatNumber } from "@company/lib/utils";

export interface BarPoint {
  /** Stable identity of the bar (a date, an hour). */
  key: string;
  /** Short text under the bar and in the tooltip's heading. */
  label: string;
  value: number;
}

const FALLBACK_WIDTH = 640;
const HEIGHT = 220;
const PAD = { top: 12, right: 8, bottom: 28, left: 36 };
const BAR_GAP = 2;
const BAR_RADIUS = 4;
const MAX_X_LABELS = 6;

/**
 * Counts per slot as thin bars on one axis — one series, so no legend; the
 * card title names it. It draws at its real pixel width, so axis text keeps
 * its size on any screen. Hover (or keyboard focus) a bar for the exact value;
 * `PointsTable` shows the same numbers as a table.
 *
 * `noun` is what a value counts, e.g. "хариулт".
 */
export function BarChart({
  points,
  ariaLabel,
  noun,
}: {
  points: readonly BarPoint[];
  ariaLabel: string;
  noun: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const { ref, width } = useElementWidth<HTMLDivElement>(FALLBACK_WIDTH);

  const top = niceCeil(Math.max(0, ...points.map((p) => p.value)));
  const plotW = width - PAD.left - PAD.right;
  const plotH = HEIGHT - PAD.top - PAD.bottom;
  const slot = points.length > 0 ? plotW / points.length : plotW;
  const barW = Math.max(2, slot - BAR_GAP);
  const y = (value: number) => PAD.top + plotH - (value / top) * plotH;
  const labels = new Set(labelIndexes(points.length, MAX_X_LABELS));
  const active = hover === null ? null : points[hover];

  return (
    <div ref={ref} className="relative">
      <svg
        width={width}
        height={HEIGHT}
        viewBox={`0 0 ${width} ${HEIGHT}`}
        role="img"
        aria-label={ariaLabel}
        className="block"
        onMouseLeave={() => setHover(null)}
      >
        {axisTicks(top).map((tick) => (
          <g key={tick}>
            <line
              x1={PAD.left}
              x2={width - PAD.right}
              y1={y(tick)}
              y2={y(tick)}
              stroke="var(--color-divider)"
              strokeWidth={1}
            />
            <text
              x={PAD.left - 6}
              y={y(tick) + 4}
              textAnchor="end"
              fontSize={11}
              className="fill-[var(--color-text-muted)]"
            >
              {formatNumber(tick)}
            </text>
          </g>
        ))}

        {points.map((p, i) => {
          const x = PAD.left + i * slot + (slot - barW) / 2;
          const height = Math.max(0, PAD.top + plotH - y(p.value));
          const r = Math.min(BAR_RADIUS, barW / 2, height);
          return (
            <g key={p.key}>
              {p.value > 0 && (
                // Rounded at the top only: the bar stays flat on the baseline.
                <path
                  d={`M${x},${y(0)} v${-(height - r)} a${r},${r} 0 0 1 ${r},${-r} h${barW - 2 * r} a${r},${r} 0 0 1 ${r},${r} v${height - r} z`}
                  fill="var(--color-primary)"
                  opacity={hover === null || hover === i ? 1 : 0.45}
                />
              )}
              {/* Full-height hit area, wider than the mark. */}
              <rect
                data-testid={`bar-${p.key}`}
                x={PAD.left + i * slot}
                y={PAD.top}
                width={slot}
                height={plotH}
                fill="transparent"
                tabIndex={0}
                aria-label={`${p.label}: ${p.value} ${noun}`}
                onMouseEnter={() => setHover(i)}
                onFocus={() => setHover(i)}
                onBlur={() => setHover(null)}
              />
              {labels.has(i) && (
                <text
                  x={PAD.left + i * slot + slot / 2}
                  y={HEIGHT - 8}
                  textAnchor="middle"
                  fontSize={11}
                  className="fill-[var(--color-text-muted)]"
                >
                  {p.label}
                </text>
              )}
            </g>
          );
        })}
      </svg>

      {active && hover !== null && (
        <div
          role="status"
          className="pointer-events-none absolute top-0 -translate-x-1/2 rounded-lg border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] px-3 py-2 text-xs shadow-lg"
          style={{ left: PAD.left + hover * slot + slot / 2 }}
        >
          <div className="text-[var(--color-text-muted)]">{active.label}</div>
          <div className="font-semibold tabular-nums text-[var(--color-text-primary)]">
            {formatNumber(active.value)} {noun}
          </div>
        </div>
      )}
    </div>
  );
}

/** The same series as a table, for people who prefer numbers or use a screen reader. */
export function PointsTable({
  points,
  heading,
  valueHeading,
  newestFirst = false,
}: {
  points: readonly BarPoint[];
  heading: string;
  valueHeading: string;
  /** A time series reads best newest first. */
  newestFirst?: boolean;
}) {
  const rows = newestFirst ? [...points].reverse() : points;
  return (
    <div className="max-h-64 overflow-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
            <th className="py-2 font-semibold">{heading}</th>
            <th className="py-2 text-right font-semibold">{valueHeading}</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => (
            <tr key={p.key} className="border-b border-[var(--color-divider)] last:border-0">
              <td className="py-2 text-[var(--color-text-secondary)]">{p.label}</td>
              <td className="py-2 text-right font-mono tabular-nums text-[var(--color-text-primary)]">
                {formatNumber(p.value)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
