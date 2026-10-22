import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { describe, expect, it } from "vitest";
import {
  AIMAGS,
  CAPITAL,
  CITIES,
  EVERYWHERE,
  EVERYWHERE_LABEL,
  TARGET_CITY_OPTIONS,
} from "./regions";

const BACKEND_REGIONS = path.resolve(
  __dirname,
  "../../../backend/src/main/java/mn/uziy/backend/common/MongolianRegions.java",
);

/** The quoted names inside `AIMAGS = List.of(...)` of the Java class. */
function backendAimags(source: string): string[] {
  const block = /AIMAGS\s*=\s*List\.of\(([^)]*)\)/.exec(source)?.[1] ?? "";
  return [...block.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
}

describe("regions", () => {
  it("lists all 21 aimags once", () => {
    expect(AIMAGS).toHaveLength(21);
    expect(new Set(AIMAGS).size).toBe(21);
  });

  it("puts the capital before the aimags", () => {
    expect(CITIES).toEqual([CAPITAL, ...AIMAGS]);
  });

  it("offers everywhere, the capital, then every aimag", () => {
    expect(TARGET_CITY_OPTIONS.map((o) => o.value)).toEqual([
      EVERYWHERE,
      ...CITIES,
    ]);
    expect(TARGET_CITY_OPTIONS[0].label).toBe(EVERYWHERE_LABEL);
    expect(TARGET_CITY_OPTIONS[1]).toEqual({ value: CAPITAL, label: CAPITAL });
  });

  it.runIf(existsSync(BACKEND_REGIONS))(
    "matches the backend's MongolianRegions character for character",
    () => {
      const source = readFileSync(BACKEND_REGIONS, "utf8");
      expect(backendAimags(source)).toEqual([...AIMAGS]);
      expect(source).toContain(`CAPITAL = "${CAPITAL}"`);
      expect(source).toContain(`EVERYWHERE = "${EVERYWHERE}"`);
    },
  );
});
