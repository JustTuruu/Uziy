import type { InsightGroup } from "@/lib/api";

/** How a hidden (too small) group is shown, e.g. "< 50". */
export function hiddenLabel(minGroupSize: number): string {
  return `< ${minGroupSize}`;
}

/** "≈ 120 хүн", or the hidden label when the group is too small. */
export function peopleLabel(people: number | null, minGroupSize: number): string {
  return people === null ? hiddenLabel(minGroupSize) : `≈ ${people.toLocaleString("en-US")} хүн`;
}

/** Each group's bar as a share of the largest shown group (hidden groups get none). */
export function groupFractions(groups: InsightGroup[]): (number | null)[] {
  const max = Math.max(0, ...groups.map((g) => g.people ?? 0));
  return groups.map((g) => (g.people === null || max === 0 ? null : g.people / max));
}
