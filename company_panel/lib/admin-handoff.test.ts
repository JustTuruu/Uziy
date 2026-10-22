import { afterEach, describe, expect, it, vi } from "vitest";
import { handoffApi } from "./api";
import { ADMIN_HANDOFF_PATH, adminHandoffUrl, handOffToAdmin } from "./admin-handoff";

describe("adminHandoffUrl", () => {
  it("puts the code in the fragment, encoded, never in the query", () => {
    const url = adminHandoffUrl("a+b/c=", "https://admin.uziy.mn");
    expect(url).toBe(`https://admin.uziy.mn${ADMIN_HANDOFF_PATH}#code=a%2Bb%2Fc%3D`);
    expect(new URL(url).search).toBe("");
  });
});

describe("handOffToAdmin", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  it("trades the admin token for a code and leaves for the admin panel without storing anything", async () => {
    const create = vi.spyOn(handoffApi, "create").mockResolvedValue({ code: "one-time", expiresAt: "x" });
    const go = vi.fn();

    await handOffToAdmin("admin-jwt", go);

    expect(create).toHaveBeenCalledWith("admin-jwt");
    expect(go).toHaveBeenCalledWith(adminHandoffUrl("one-time"));
    expect(window.localStorage.length).toBe(0);
  });

  it("rejects (and goes nowhere) when the code cannot be made", async () => {
    vi.spyOn(handoffApi, "create").mockRejectedValue(new Error("down"));
    const go = vi.fn();
    await expect(handOffToAdmin("admin-jwt", go)).rejects.toThrow("down");
    expect(go).not.toHaveBeenCalled();
  });
});
