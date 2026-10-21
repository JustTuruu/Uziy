import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import path from "node:path";

/** Custom properties declared in the first block that matches [selector]. */
function tokens(file: string, selector: RegExp): Record<string, string> {
  const css = readFileSync(file, "utf8");
  const block = css.match(selector)?.[1] ?? "";
  const out: Record<string, string> = {};
  for (const m of block.matchAll(/(--[\w-]+)\s*:\s*([^;]+);/g)) {
    out[m[1]] = m[2].trim();
  }
  return out;
}

const admin = tokens(
  path.join(__dirname, "globals.css"),
  /:root\s*\{([\s\S]*?)\n\}/,
);
const shared = tokens(
  path.join(__dirname, "../../packages/ui/src/theme.css"),
  /@theme\s*\{([\s\S]*?)\n\}/,
);

/** WCAG 2.x relative luminance of a #rrggbb colour. */
function luminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrast(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

/** WCAG AA for normal-size text. */
const AA = 4.5;

const color = (name: string) => {
  const value = admin[`--color-${name}`];
  expect(value, `--color-${name}`).toMatch(/^#[0-9a-f]{6}$/i);
  return value;
};

describe("admin light palette", () => {
  it("is a plain white page", () => {
    expect(color("background")).toBe("#ffffff");
    expect(color("surface")).toBe("#ffffff");
    expect(color("sidebar")).toBe("#ffffff");
  });

  it("only overrides tokens the shared theme defines (no typos)", () => {
    const unknown = Object.keys(admin).filter((k) => !(k in shared));
    expect(unknown).toEqual([]);
  });

  it.each([
    "text-primary",
    "text-secondary",
    "text-muted",
    "primary",
    "accent",
    "success",
    "danger",
    "warning",
  ])("%s reads as text on white and on the grey surfaces", (name) => {
    for (const bg of ["background", "surface-elevated", "surface-hover"]) {
      expect(contrast(color(name), color(bg)), `${name} on ${bg}`).toBeGreaterThanOrEqual(AA);
    }
  });

  it.each([
    ["on-primary", "primary"],
    ["on-primary", "primary-dark"],
    ["on-success", "success"],
    ["on-danger", "danger"],
  ])("%s text is readable on a %s fill", (fg, bg) => {
    expect(contrast(color(fg), color(bg))).toBeGreaterThanOrEqual(AA);
  });
});

describe("shared dark defaults (company panel) are unchanged", () => {
  it("keeps the dark ink on gold / green fills it always had", () => {
    expect(shared["--color-on-primary"]).toBe("#14110a");
    expect(shared["--color-on-success"]).toBe("#04120c");
    expect(shared["--color-on-danger"]).toBe("#ffffff");
    expect(shared["--color-primary-deep"]).toBe("#b8860b");
    expect(shared["--color-background"]).toBe("#0a0b0e");
    expect(shared["--color-sidebar"]).toBe(
      "color-mix(in oklab, var(--color-surface) 92%, black)",
    );
  });
});
