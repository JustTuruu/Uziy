import { describe, expect, it } from "vitest";
import { RATING_LABELS, takesOptions } from "./survey";

describe("takesOptions", () => {
  it("is true for the choice types", () => {
    expect(takesOptions("SINGLE_CHOICE")).toBe(true);
    expect(takesOptions("MULTI_CHOICE")).toBe(true);
  });

  it("is false for text and rating, whose answers are not typed by the company", () => {
    expect(takesOptions("TEXT")).toBe(false);
    expect(takesOptions("RATING")).toBe(false);
  });
});

describe("RATING_LABELS", () => {
  it("runs worst to best", () => {
    expect([...RATING_LABELS]).toEqual(["Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн"]);
  });
});
