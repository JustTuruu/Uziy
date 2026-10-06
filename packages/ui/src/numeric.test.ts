import { describe, expect, it } from "vitest";
import { parseIntInput, sanitizeIntInput } from "./numeric";

describe("sanitizeIntInput", () => {
  it("keeps digits only", () => {
    expect(sanitizeIntInput("1a2,3 ₮")).toBe("123");
  });

  it("drops leading zeros but keeps a lone zero and an empty field", () => {
    expect(sanitizeIntInput("007")).toBe("7");
    expect(sanitizeIntInput("0")).toBe("0");
    expect(sanitizeIntInput("")).toBe("");
  });
});

describe("parseIntInput", () => {
  it("parses digits and treats an empty or invalid field as 0", () => {
    expect(parseIntInput("42")).toBe(42);
    expect(parseIntInput("")).toBe(0);
  });
});
