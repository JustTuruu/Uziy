import { describe, expect, it } from "vitest";
import { cn } from "./cn";

describe("cn", () => {
  it("joins truthy class names and skips falsy ones", () => {
    expect(cn("a", false && "b", undefined, "c")).toBe("a c");
  });

  it("lets the later Tailwind utility win a conflict", () => {
    expect(cn("px-2 py-1", "px-4")).toBe("py-1 px-4");
  });
});
