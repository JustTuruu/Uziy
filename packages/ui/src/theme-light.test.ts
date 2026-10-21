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
  path.join(__dirname, "theme-light.css"),
  /:root\s*\{([\s\S]*?)\n\}/,
);
const shared = tokens(
  path.join(__dirname, "theme.css"),
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

/** Tailwind's own theme tokens (not in theme.css) the admin may override. */
const TAILWIND_TOKENS = ["--text-xs", "--text-sm"];

/** Tailwind's defaults for those, in rem. */
const TAILWIND_TEXT: Record<string, number> = {
  "--text-xs": 0.75,
  "--text-sm": 0.875,
};

/** The UI type scale from smallest to largest. */
const TEXT_SCALE = [
  "--text-4xs",
  "--text-3xs",
  "--text-2xs",
  "--text-xs",
  "--text-ui",
  "--text-sm",
];

const rem = (value: string) => {
  expect(value).toMatch(/^[\d.]+rem$/);
  return parseFloat(value);
};

/** WCAG AA for normal-size text. */
const AA = 4.5;

const color = (name: string) => {
  const value = admin[`--color-${name}`];
  expect(value, `--color-${name}`).toMatch(/^#[0-9a-f]{6}$/i);
  return value;
};

describe("light console palette (admin + company)", () => {
  it("is a plain white page", () => {
    expect(color("background")).toBe("#ffffff");
    expect(color("surface")).toBe("#ffffff");
    expect(color("sidebar")).toBe("#ffffff");
  });

  it("only overrides tokens the shared theme (or Tailwind) defines", () => {
    const unknown = Object.keys(admin).filter(
      (k) => !(k in shared) && !TAILWIND_TOKENS.includes(k),
    );
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

describe("light console type", () => {
  const sharedSize = (token: string) =>
    token in shared ? rem(shared[token]) : TAILWIND_TEXT[token];

  it.each(TEXT_SCALE)("%s is larger than the shared default", (token) => {
    expect(rem(admin[token])).toBeGreaterThan(sharedSize(token));
  });

  it("keeps the scale in order and nothing under 10px", () => {
    const sizes = TEXT_SCALE.map((t) => rem(admin[t]));
    expect([...sizes].sort((a, b) => a - b)).toEqual(sizes);
    expect(new Set(sizes).size).toBe(sizes.length);
    expect(sizes[0] * 16).toBeGreaterThanOrEqual(10);
  });

  it("uses Rubik first, with system fallbacks", () => {
    expect(admin["--font-sans"]).toMatch(/^var\(--font-rubik\),/);
    expect(admin["--font-sans"]).toContain("sans-serif");
  });

  it("loads the Rubik subsets Mongolian text and ₮ need", () => {
    const layout = readFileSync(path.join(__dirname, "fonts.ts"), "utf8");
    expect(layout).toMatch(/Rubik\(\{/);
    expect(layout).toContain('variable: "--font-rubik"');
    // Ө / Ү live in cyrillic-ext, the ₮ sign in latin-ext.
    for (const subset of ["cyrillic", "cyrillic-ext", "latin", "latin-ext"]) {
      expect(layout).toContain(`"${subset}"`);
    }
  });
});

describe("shared dark defaults (company panel) are unchanged", () => {
  it("keeps the small type sizes the components had in px", () => {
    expect(shared["--text-4xs"]).toBe("0.5625rem"); // 9px
    expect(shared["--text-3xs"]).toBe("0.625rem"); // 10px
    expect(shared["--text-2xs"]).toBe("0.6875rem"); // 11px
    expect(shared["--text-ui"]).toBe("0.8125rem"); // 13px
    expect(shared["--font-sans"]).toMatch(/^"Inter",/);
  });

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
