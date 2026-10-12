import type { AnalyticsReport, AnalyticsSlice, DailyResponses } from "./api";
import { formatTugrik } from "./utils";

/** Time windows offered above the charts. */
export const DAY_OPTIONS = [
  { value: "7", label: "7 хоног" },
  { value: "30", label: "30 хоног" },
  { value: "90", label: "90 хоног" },
] as const;

export const DEFAULT_DAYS = "30";

/** Fewer responses than this and the backend withholds the audience (mirrors AnalyticsService.MIN_AUDIENCE_SAMPLE). */
/** A segment needs this many answerers before its answers are shown (mirrors AnalyticsService.MIN_SEGMENT_SAMPLE). */
export const MIN_SEGMENT_SAMPLE = 5;

export const MIN_AUDIENCE_SAMPLE = 5;

const GENDER_LABEL: Record<string, string> = {
  MALE: "Эрэгтэй",
  FEMALE: "Эмэгтэй",
};

/** "MALE" → "Эрэгтэй"; anything unknown is shown as it came. */
export function genderLabel(value: string): string {
  return GENDER_LABEL[value] ?? value;
}

/** `count` as a whole-number share of `total`, 0 when there is nothing to share. */
export function share(count: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((count / total) * 100);
}

/** Total of a list of slices. */
export function sliceTotal(slices: readonly AnalyticsSlice[]): number {
  return slices.reduce((sum, s) => sum + s.count, 0);
}

/** "37%" — one decimal only below 10 so small shares stay readable. */
export function formatPercent(value: number): string {
  const rounded = value < 10 ? Math.round(value * 10) / 10 : Math.round(value);
  return `${rounded}%`;
}

/**
 * The smallest "nice" number (1, 2, 5 × a power of ten) that is at least `max`,
 * so a chart's top gridline is a round figure. 0 or less gives 1.
 */
export function niceCeil(max: number): number {
  if (max <= 0) return 1;
  const exponent = Math.floor(Math.log10(max));
  const base = 10 ** exponent;
  for (const step of [1, 2, 5, 10]) {
    if (step * base >= max) return step * base;
  }
  return 10 * base;
}

/** Evenly spaced gridline values from 0 to `top` (inclusive), `count` intervals. */
export function axisTicks(top: number, count = 4): number[] {
  return Array.from({ length: count + 1 }, (_, i) => (top / count) * i);
}

/** "2026-10-07" → "10.07". */
export function shortDate(iso: string): string {
  return `${iso.slice(5, 7)}.${iso.slice(8, 10)}`;
}

/** Indexes of the x labels to print so they never crowd: first, last and evenly between. */
export function labelIndexes(length: number, maxLabels = 6): number[] {
  if (length <= 0) return [];
  if (length <= maxLabels) return Array.from({ length }, (_, i) => i);
  const step = (length - 1) / (maxLabels - 1);
  const picked = new Set<number>();
  for (let i = 0; i < maxLabels; i++) picked.add(Math.round(i * step));
  return [...picked].sort((a, b) => a - b);
}

/** Busiest day of the series, or null when there were no responses at all. */
export function peakDay(daily: readonly DailyResponses[]): DailyResponses | null {
  let best: DailyResponses | null = null;
  for (const d of daily) {
    if (d.responses > 0 && (best === null || d.responses > best.responses)) best = d;
  }
  return best;
}

/** The strongest tint of a heat-map cell: the share of the primary colour mixed into the surface. */
export const MAX_TINT_PERCENT = 55;

/** How much primary colour a cell showing `percent` (0..100) is tinted with. */
export function segmentTint(percent: number): number {
  const clamped = Math.min(100, Math.max(0, percent));
  return Math.round((clamped / 100) * MAX_TINT_PERCENT * 10) / 10;
}

// --- Series for the charts --------------------------------------------------

export interface ChartPoint {
  key: string;
  label: string;
  value: number;
}

/** The daily series as chart points, labelled "MM.DD". */
export function dailyPoints(daily: readonly DailyResponses[]): ChartPoint[] {
  return daily.map((d) => ({ key: d.date, label: shortDate(d.date), value: d.responses }));
}

/** "19:00" for hour 19. */
export function hourLabel(hour: number): string {
  return `${String(hour).padStart(2, "0")}:00`;
}

/** The 24 hourly counts as chart points, one per hour of the day. */
export function hourlyPoints(hourly: readonly number[]): ChartPoint[] {
  return hourly.map((count, hour) => ({
    key: `h${hour}`,
    label: hourLabel(hour),
    value: count,
  }));
}

/** The single busiest hour of the day, or null when there are no responses. */
export function peakHour(
  hourly: readonly number[],
): { hour: number; responses: number; sharePercent: number } | null {
  const total = hourly.reduce((a, b) => a + b, 0);
  if (total === 0) return null;
  let hour = 0;
  hourly.forEach((count, h) => {
    if (count > hourly[hour]) hour = h;
  });
  return { hour, responses: hourly[hour], sharePercent: share(hourly[hour], total) };
}

/**
 * How the latest seven days compare with the seven before, as a percentage
 * change; null when the series is shorter than fourteen days or the earlier
 * week had no responses (a change from zero has no percentage).
 */
export function weekOverWeek(daily: readonly DailyResponses[]): number | null {
  if (daily.length < 14) return null;
  const sum = (rows: readonly DailyResponses[]) => rows.reduce((a, d) => a + d.responses, 0);
  const latest = sum(daily.slice(-7));
  const before = sum(daily.slice(-14, -7));
  if (before === 0) return null;
  return Math.round(((latest - before) / before) * 100);
}

// --- Plain-language findings ---------------------------------------------------

export interface Insight {
  tone: "info" | "success" | "warning";
  text: string;
}

/** Fewer responses than this and "busiest hour" would just be noise. */
export const MIN_INSIGHT_SAMPLE = 10;

/** A budget that runs out within this many days is worth a warning. */
export const BUDGET_WARNING_DAYS = 7;

/** A campaign needs this many responses before its price is compared with others'. */
const MIN_RESPONSES_TO_COMPARE_COST = 3;

/**
 * What a company should take away from the numbers, in order of use: when to
 * expect answers, whether it is speeding up or slowing down, which budget is
 * about to run dry, what the cheapest answers cost, which running campaign is
 * getting nothing. Empty until there is something worth saying.
 */
export function buildInsights(
  report: AnalyticsReport,
  selectedCampaignId: number | null,
): Insight[] {
  const out: Insight[] = [];

  const totalByHour = report.hourly.reduce((a, b) => a + b, 0);
  const peak = peakHour(report.hourly);
  if (peak && totalByHour >= MIN_INSIGHT_SAMPLE) {
    out.push({
      tone: "info",
      text: `Хариулт хамгийн их ${hourLabel(peak.hour)}–${hourLabel((peak.hour + 1) % 24)} цагт ирдэг (${peak.sharePercent}%).`,
    });
  }

  const change = weekOverWeek(report.daily);
  if (change !== null) {
    out.push(
      change > 0
        ? { tone: "success", text: `Сүүлийн 7 хоногт өмнөх 7 хоногоос ${change}%-иар олон хариулт ирлээ.` }
        : change < 0
          ? { tone: "warning", text: `Сүүлийн 7 хоногт өмнөх 7 хоногоос ${-change}%-иар цөөн хариулт ирлээ.` }
          : { tone: "info", text: "Сүүлийн 7 хоногийн хариулт өмнөх 7 хоногтой адил байна." },
    );
  }

  const inScope = report.campaigns.filter(
    (c) => selectedCampaignId === null || c.campaignId === selectedCampaignId,
  );

  for (const c of inScope) {
    if (c.daysLeft !== null && c.daysLeft <= BUDGET_WARNING_DAYS) {
      out.push({
        tone: "warning",
        text: `${c.title}: одоогийн хурдаар ойролцоогоор ${c.daysLeft} хоногт бюджет дуусна (үлдсэн ${c.remainingResponses} хариулт).`,
      });
    }
  }

  const priced = report.campaigns.filter(
    (c) => c.costPerResponse !== null && c.responses >= MIN_RESPONSES_TO_COMPARE_COST,
  );
  if (selectedCampaignId === null && priced.length >= 2) {
    const sorted = [...priced].sort((a, b) => a.costPerResponse! - b.costPerResponse!);
    const cheapest = sorted[0];
    const dearest = sorted[sorted.length - 1];
    if (cheapest.costPerResponse! < dearest.costPerResponse!) {
      out.push({
        tone: "info",
        text: `Хамгийн хямд хариулт: ${cheapest.title} (${formatTugrik(cheapest.costPerResponse!)}). Хамгийн үнэтэй нь: ${dearest.title} (${formatTugrik(dearest.costPerResponse!)}).`,
      });
    }
  }

  for (const c of inScope) {
    if (c.status === "ACTIVE" && c.responsesLast7Days === 0) {
      out.push({
        tone: "warning",
        text: `${c.title} идэвхтэй ч сүүлийн 7 хоногт хариулт ирээгүй байна.`,
      });
    }
  }

  return out;
}
