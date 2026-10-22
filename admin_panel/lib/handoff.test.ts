import { describe, expect, it } from "vitest";
import { SIGN_IN_URL, codeFromHash } from "./handoff";

describe("codeFromHash", () => {
  it("reads and decodes the code from the fragment", () => {
    expect(codeFromHash("#code=a%2Bb%2Fc%3D")).toBe("a+b/c=");
    expect(codeFromHash("code=xyz")).toBe("xyz");
  });

  it("is null for a missing or empty code", () => {
    expect(codeFromHash("")).toBeNull();
    expect(codeFromHash("#")).toBeNull();
    expect(codeFromHash("#code=")).toBeNull();
    expect(codeFromHash("#other=1")).toBeNull();
  });
});

describe("SIGN_IN_URL", () => {
  it("is the company panel's login page", () => {
    expect(SIGN_IN_URL).toMatch(/\/login$/);
  });
});
