import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

describe("page font", () => {
  // Ө ө Ү ү live in the cyrillic-ext subset; without it they rendered in a fallback font mid-word (2026-10-22).
  it("loads the subset that carries the Mongolian letters", () => {
    const layout = readFileSync(join(__dirname, "layout.tsx"), "utf8");
    expect(layout).toMatch(/subsets:\s*\[[^\]]*"cyrillic-ext"/);
  });
});
