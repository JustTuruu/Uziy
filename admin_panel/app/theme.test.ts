import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import path from "node:path";

// The palette, type scale and contrast rules are tested next to the shared
// file (packages/ui/src/theme-light.test.ts); here: this panel really uses them.
const read = (file: string) => readFileSync(path.join(__dirname, file), "utf8");

describe("admin panel look", () => {
  it("imports the light console theme after the shared base theme", () => {
    const css = read("globals.css");
    const base = css.indexOf("packages/ui/src/theme.css");
    const light = css.indexOf("packages/ui/src/theme-light.css");
    expect(base).toBeGreaterThan(-1);
    expect(light).toBeGreaterThan(base);
    expect(css).not.toMatch(/:root\s*\{/); // no private copy of the palette
  });

  it("puts the shared console font on <html>", () => {
    const layout = read("layout.tsx");
    expect(layout).toContain('import { consoleFont } from "@uziy/ui/fonts"');
    expect(layout).toContain("${consoleFont.variable}");
    expect(layout).not.toContain("next/font/google"); // one definition only
  });
});
