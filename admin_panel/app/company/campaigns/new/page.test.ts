import { describe, expect, it } from "vitest";
import { computeVideoCostPerView } from "./page";

describe("computeVideoCostPerView", () => {
  it("returns the base 500₮ for the widest possible targeting", () => {
    expect(
      computeVideoCostPerView({
        gender: "ALL",
        minAge: 18,
        maxAge: 60, // >10 year window
        city: "ALL",
      }),
    ).toBe(500);
  });

  it("adds 200₮ when the gender is locked", () => {
    const wide = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 60, city: "ALL",
    });
    const genderLocked = computeVideoCostPerView({
      gender: "FEMALE", minAge: 18, maxAge: 60, city: "ALL",
    });
    expect(genderLocked - wide).toBe(200);
  });

  it("adds 150₮ when the age window is ≤10 years", () => {
    const wide = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 45, city: "ALL",
    });
    const narrow = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 28, city: "ALL",
    });
    expect(narrow - wide).toBe(150);
  });

  it("adds 200₮ when a specific city is targeted", () => {
    const wide = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 60, city: "ALL",
    });
    const city = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 60, city: "Улаанбаатар",
    });
    expect(city - wide).toBe(200);
  });

  it("stacks all three modifiers (gender + narrow age + city)", () => {
    expect(
      computeVideoCostPerView({
        gender: "MALE",
        minAge: 20,
        maxAge: 25, // 5-year window ≤10 → +150
        city: "Улаанбаатар",
      }),
    ).toBe(500 + 200 + 150 + 200);
  });

  it("treats an exactly-10-year window as narrow (boundary check)", () => {
    const at10 = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 28, city: "ALL",
    });
    const at11 = computeVideoCostPerView({
      gender: "ALL", minAge: 18, maxAge: 29, city: "ALL",
    });
    expect(at10 - at11).toBe(150);
  });
});
