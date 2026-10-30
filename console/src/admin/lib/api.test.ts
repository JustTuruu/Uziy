import { afterEach, describe, expect, it, vi } from "vitest";
import { auth } from "./api";

describe("adminApi.updateSettings", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  it("updateSettings PATCHes /admin/platform-settings with the commission body", async () => {
    auth.setToken("admin-tok");
    let captured: RequestInit | undefined;
    let capturedUrl: RequestInfo | URL | undefined;
    globalThis.fetch = vi.fn(async (url, init) => {
      capturedUrl = url;
      captured = init ?? {};
      return new Response(
        JSON.stringify({
          commissionPercent: 35,
          surveyCommissionPercent: 25,
          minRewardPerViewer: 150,
          updatedAt: "2026-09-28T11:00:00Z",
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }) as typeof fetch;

    const { adminApi } = await import("./api");
    const res = await adminApi.updateSettings({
      commissionPercent: 35,
      surveyCommissionPercent: 25,
      minRewardPerViewer: 150,
    });

    expect(String(capturedUrl)).toContain("/admin/platform-settings");
    expect(captured!.method).toBe("PATCH");
    expect(
      (captured!.headers as Record<string, string>).Authorization,
    ).toBe("Bearer admin-tok");
    expect(JSON.parse(captured!.body as string)).toEqual({
      commissionPercent: 35,
      surveyCommissionPercent: 25,
      minRewardPerViewer: 150,
    });
    expect(res.commissionPercent).toBe(35);
  });
});


describe("adminsApi", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  it("lists with GET and creates with POST on /admin/admins, signed in", async () => {
    auth.setToken("admin-tok");
    const calls: { url: string; init: RequestInit }[] = [];
    globalThis.fetch = vi.fn(async (url, init) => {
      calls.push({ url: String(url), init: init ?? {} });
      const body = init?.method === "POST" ? { id: 5, phoneNumber: "88112235", createdAt: "x" } : [];
      return new Response(JSON.stringify(body), {
        status: init?.method === "POST" ? 201 : 200,
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;

    const { adminsApi } = await import("./api");
    expect(await adminsApi.list()).toEqual([]);
    const created = await adminsApi.create({ phoneNumber: "88112235", password: "temp-pass1" });

    expect(created.id).toBe(5);
    expect(calls[0].url).toMatch(/\/admin\/admins$/);
    expect(calls[0].init.method ?? "GET").toBe("GET");
    expect(calls[1].init.method).toBe("POST");
    expect(JSON.parse(String(calls[1].init.body))).toEqual({
      phoneNumber: "88112235",
      password: "temp-pass1",
    });
    expect((calls[1].init.headers as Record<string, string>).Authorization).toBe("Bearer admin-tok");
  });

});

describe("adminApi.moderate", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("sends the campaign's commission with an approval, and none otherwise", async () => {
    const urls: string[] = [];
    globalThis.fetch = vi.fn(async (url) => {
      urls.push(String(url));
      return new Response(JSON.stringify({}), { status: 200 });
    }) as typeof fetch;
    const { adminApi } = await import("./api");

    await adminApi.moderate(7, "ACTIVE", 40);
    await adminApi.moderate(8, "REJECTED");

    expect(urls[0]).toMatch(/\/admin\/campaigns\/7\/moderate\?decision=ACTIVE&commissionPercent=40$/);
    expect(urls[1]).toMatch(/\/admin\/campaigns\/8\/moderate\?decision=REJECTED$/);
  });
});
