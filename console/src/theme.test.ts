import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import path from "node:path";

// The palette, type scale and contrast rules are tested next to the shared files (packages/ui/src/theme-light.test.ts);
// here: this app really uses them.
const read = (file: string) => readFileSync(path.join(__dirname, file), "utf8");

describe("console look", () => {
  it("imports the light console theme after the shared base theme", () => {
    const css = read("globals.css");
    const base = css.indexOf("packages/ui/src/theme.css");
    const light = css.indexOf("packages/ui/src/theme-light.css");
    expect(base).toBeGreaterThan(-1);
    expect(light).toBeGreaterThan(base);
    expect(css).not.toMatch(/:root\s*\{/); // no private copy of the palette
  });

  it("loads the shared console font, defined once in the kit", () => {
    const css = read("globals.css");
    expect(css).toContain("packages/ui/src/fonts.css");
    expect(css).not.toContain("@fontsource"); // one definition only: the kit's fonts.css
  });

  it("speaks Mongolian to the browser", () => {
    expect(read("../index.html")).toContain('<html lang="mn"');
  });
});
