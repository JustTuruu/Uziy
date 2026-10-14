import { describe, expect, it } from "vitest";
import {
  AIMAGS,
  CAPITAL,
  EVERYWHERE,
  EVERYWHERE_LABEL,
  TARGET_CITY_OPTIONS,
} from "./regions";

describe("regions", () => {
  it("lists all 21 aimags once", () => {
    expect(AIMAGS).toHaveLength(21);
    expect(new Set(AIMAGS).size).toBe(21);
  });

  it("offers everywhere, the capital, then every aimag", () => {
    expect(TARGET_CITY_OPTIONS.map((o) => o.value)).toEqual([
      EVERYWHERE,
      CAPITAL,
      ...AIMAGS,
    ]);
    expect(TARGET_CITY_OPTIONS[0].label).toBe(EVERYWHERE_LABEL);
  });

  it("uses the backend's exact aimag names, not town names", () => {
    expect(AIMAGS).toContain("Дархан-Уул");
    expect(AIMAGS).toContain("Орхон");
    expect(AIMAGS).not.toContain("Дархан" as never);
    expect(AIMAGS).not.toContain("Эрдэнэт" as never);
  });
});
