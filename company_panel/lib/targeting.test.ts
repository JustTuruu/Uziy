import { describe, expect, it } from "vitest";
import {
  AGE_OUT_OF_RANGE_MESSAGE,
  AGE_RANGE_TOO_NARROW_MESSAGE,
  MIN_AGE_SPAN,
  ageRangeError,
} from "./targeting";

describe("ageRangeError", () => {
  it.each([
    [18, 45],
    [13, 99],
    [18, 18 + MIN_AGE_SPAN],
  ])("accepts %i–%i", (min, max) => {
    expect(ageRangeError(min, max)).toBeNull();
  });

  // Regression (2026-10-22 audit): one exact age in one aimag singled out a few viewers.
  it.each([
    [30, 30],
    [30, 30 + MIN_AGE_SPAN - 1],
  ])("refuses the too narrow %i–%i", (min, max) => {
    expect(ageRangeError(min, max)).toBe(AGE_RANGE_TOO_NARROW_MESSAGE);
  });

  it.each([
    [12, 40],
    [18, 100],
    [40, 30],
    [0, 0], // both fields emptied
  ])("refuses the out-of-range or reversed %i–%i", (min, max) => {
    expect(ageRangeError(min, max)).toBe(AGE_OUT_OF_RANGE_MESSAGE);
  });

  it("words the narrow-range refusal exactly like the backend", () => {
    expect(AGE_RANGE_TOO_NARROW_MESSAGE).toBe(
      "Их нас бага наснаас дор хаяж 5 жилээр их байх ёстой — цөөхөн хүнд чиглэсэн судалгаанаас хариулагч хэн болох нь танигдах эрсдэлтэй",
    );
  });
});
