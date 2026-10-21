import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { cn, EXTRA_TEXT_SIZES } from "./cn";

describe("cn", () => {
  it("joins truthy class names and skips falsy ones", () => {
    expect(cn("a", false && "b", undefined, "c")).toBe("a c");
  });

  it("lets the later Tailwind utility win a conflict", () => {
    expect(cn("px-2 py-1", "px-4")).toBe("py-1 px-4");
  });

  it.each(EXTRA_TEXT_SIZES)(
    "keeps text-%s next to a text colour (it is a size, not a colour)",
    (size) => {
      expect(cn(`text-${size}`, "text-[var(--color-text-secondary)]")).toBe(
        `text-${size} text-[var(--color-text-secondary)]`,
      );
    },
  );

  it("still resolves two sizes to the later one", () => {
    expect(cn("text-ui", "text-sm")).toBe("text-sm");
    expect(cn("text-xs", "text-2xs")).toBe("text-2xs");
  });

  it("knows every --text-* step theme.css defines", () => {
    const css = readFileSync(path.join(__dirname, "theme.css"), "utf8");
    const defined = [...css.matchAll(/--text-([\w-]+):/g)].map((m) => m[1]);
    expect(defined.sort()).toEqual([...EXTRA_TEXT_SIZES].sort());
  });
});
