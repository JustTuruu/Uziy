import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, apiFetch, auth, authApi } from "./api";

describe("auth (localStorage helpers)", () => {
  beforeEach(() => window.localStorage.clear());

  it("round-trips a token", () => {
    auth.setToken("abc.def.ghi");
    expect(auth.getToken()).toBe("abc.def.ghi");
  });

  it("round-trips the current user", () => {
    const me = {
      id: 1, phoneNumber: "88112233", role: "ADMIN" as const,
      gender: null, age: null, city: null, balance: 0,
      isVerified: true, companyName: null,
    };
    auth.setUser(me);
    expect(auth.getUser()).toEqual(me);
  });

  it("clear() wipes both token and user", () => {
    auth.setToken("x");
    auth.setUser({
      id: 1, phoneNumber: "1", role: "ADMIN",
      gender: null, age: null, city: null, balance: 0,
      isVerified: true, companyName: null,
    });
    auth.clear();
    expect(auth.getToken()).toBeNull();
    expect(auth.getUser()).toBeNull();
  });

  it("getUser returns null when JSON is corrupted", () => {
    window.localStorage.setItem("uziy.user", "{not json");
    expect(auth.getUser()).toBeNull();
  });
});

describe("apiFetch", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
    vi.restoreAllMocks();
  });

  function mockFetch(status: number, body: unknown, capture?: (req: RequestInit) => void) {
    globalThis.fetch = vi.fn(async (_url: RequestInfo | URL, init?: RequestInit) => {
      capture?.(init ?? {});
      return new Response(typeof body === "string" ? body : JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;
  }

  it("returns parsed JSON on 2xx", async () => {
    mockFetch(200, { hello: "world" });
    const res = await apiFetch<{ hello: string }>("/x");
    expect(res.hello).toBe("world");
  });

  it("sends Authorization header when a token is set", async () => {
    auth.setToken("tok");
    let captured: RequestInit | undefined;
    mockFetch(200, {}, (r) => (captured = r));
    await apiFetch("/x");
    expect((captured!.headers as Record<string, string>).Authorization).toBe(
      "Bearer tok",
    );
  });

  it("skips Authorization header when opts.anonymous = true", async () => {
    auth.setToken("tok");
    let captured: RequestInit | undefined;
    mockFetch(200, {}, (r) => (captured = r));
    await apiFetch("/x", { anonymous: true });
    expect((captured!.headers as Record<string, string>).Authorization).toBeUndefined();
  });

  it("serializes body as JSON with content-type header", async () => {
    let captured: RequestInit | undefined;
    mockFetch(200, {}, (r) => (captured = r));
    await apiFetch("/x", { method: "POST", body: { a: 1 } });
    expect(captured!.method).toBe("POST");
    expect(captured!.body).toBe(JSON.stringify({ a: 1 }));
    expect((captured!.headers as Record<string, string>)["Content-Type"]).toBe(
      "application/json",
    );
  });

  it("throws ApiError with status + parsed body on 4xx", async () => {
    mockFetch(409, { message: "Already rewarded" });
    await expect(apiFetch("/x")).rejects.toMatchObject({
      name: "ApiError",
      status: 409,
      message: "Already rewarded",
    });
  });

  it("throws ApiError on 5xx even when body is empty", async () => {
    mockFetch(500, "");
    const err = await apiFetch("/x").catch((e) => e);
    expect(err).toBeInstanceOf(ApiError);
    expect((err as ApiError).status).toBe(500);
  });
});

describe("authApi.login", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("POSTs to /auth/login and skips the Authorization header", async () => {
    let captured: RequestInit | undefined;
    let capturedUrl: RequestInfo | URL | undefined;
    globalThis.fetch = vi.fn(async (url, init) => {
      capturedUrl = url;
      captured = init ?? {};
      return new Response(
        JSON.stringify({ token: "t", user: { id: 1 } }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }) as typeof fetch;

    const res = await authApi.login({ phoneNumber: "88112233", password: "password" });

    expect(String(capturedUrl)).toContain("/auth/login");
    expect(captured!.method).toBe("POST");
    expect((captured!.headers as Record<string, string>).Authorization).toBeUndefined();
    expect(res.token).toBe("t");
  });
});

describe("platformSettingsApi + adminApi.updateSettings", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  it("get() calls /platform-settings anonymously (no auth header)", async () => {
    auth.setToken("tok");
    let captured: RequestInit | undefined;
    let capturedUrl: RequestInfo | URL | undefined;
    globalThis.fetch = vi.fn(async (url, init) => {
      capturedUrl = url;
      captured = init ?? {};
      return new Response(
        JSON.stringify({
          commissionPercent: 30,
          minRewardPerViewer: 100,
          updatedAt: "2026-09-28T10:00:00Z",
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }) as typeof fetch;

    const { platformSettingsApi } = await import("./api");
    const res = await platformSettingsApi.get();

    expect(String(capturedUrl)).toContain("/platform-settings");
    expect(captured!.method ?? "GET").toBe("GET");
    expect(
      (captured!.headers as Record<string, string>).Authorization,
    ).toBeUndefined();
    expect(res.commissionPercent).toBe(30);
    expect(res.minRewardPerViewer).toBe(100);
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
          minRewardPerViewer: 150,
          updatedAt: "2026-09-28T11:00:00Z",
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      );
    }) as typeof fetch;

    const { adminApi } = await import("./api");
    const res = await adminApi.updateSettings({
      commissionPercent: 35,
      minRewardPerViewer: 150,
    });

    expect(String(capturedUrl)).toContain("/admin/platform-settings");
    expect(captured!.method).toBe("PATCH");
    expect(
      (captured!.headers as Record<string, string>).Authorization,
    ).toBe("Bearer admin-tok");
    expect(JSON.parse(captured!.body as string)).toEqual({
      commissionPercent: 35,
      minRewardPerViewer: 150,
    });
    expect(res.commissionPercent).toBe(35);
  });
});

describe("companyApi — campaign creation, payment, status", () => {
  const originalFetch = globalThis.fetch;
  let calls: { url: string; init: RequestInit }[] = [];

  function respondWith(status: number, body: unknown) {
    calls = [];
    globalThis.fetch = vi.fn(async (url: RequestInfo | URL, init?: RequestInit) => {
      calls.push({ url: String(url), init: init ?? {} });
      return new Response(JSON.stringify(body), {
        status,
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;
  }

  beforeEach(() => auth.setToken("company-tok"));
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  const baseBody = {
    title: "Шинэ 5G багц",
    hasVideo: false,
    videoUrl: "",
    durationSeconds: 0,
    targetGender: "ALL" as const,
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 1_000_000,
    questions: [
      { prompt: "Та 5G ашигладаг уу?", type: "TEXT" as const, options: [], required: true },
    ],
  };

  it("create() POSTs the budget + targetViewers and no costPerView", async () => {
    respondWith(200, { id: 7, status: "AWAITING_PAYMENT" });
    const { companyApi } = await import("./api");

    const res = await companyApi.create({ ...baseBody, targetViewers: 1_000 });

    expect(calls[0].url).toMatch(/\/company\/campaigns$/);
    expect(calls[0].init.method).toBe("POST");
    const sent = JSON.parse(calls[0].init.body as string);
    expect(sent.totalBudget).toBe(1_000_000);
    expect(sent.targetViewers).toBe(1_000);
    expect(sent).not.toHaveProperty("rewardPerUser");
    expect(sent).not.toHaveProperty("costPerView");
    expect(res.status).toBe("AWAITING_PAYMENT");
  });

  it("create() can drive pricing by rewardPerUser instead", async () => {
    respondWith(200, { id: 8 });
    const { companyApi } = await import("./api");

    await companyApi.create({ ...baseBody, rewardPerUser: 500 });

    const sent = JSON.parse(calls[0].init.body as string);
    expect(sent.rewardPerUser).toBe(500);
    expect(sent).not.toHaveProperty("targetViewers");
  });

  it("pay() POSTs /company/campaigns/{id}/pay with the auth header", async () => {
    respondWith(200, {
      campaign: { id: 42, status: "PENDING", paidAt: "2026-09-28T12:00:00Z" },
      payment: { id: 1, campaignId: 42, reference: "UZ-20260928-42", status: "PAID" },
    });
    const { companyApi } = await import("./api");

    const res = await companyApi.pay(42);

    expect(calls[0].url).toMatch(/\/company\/campaigns\/42\/pay$/);
    expect(calls[0].init.method).toBe("POST");
    expect(calls[0].init.body).toBeUndefined();
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(
      "Bearer company-tok",
    );
    expect(res.campaign.status).toBe("PENDING");
    expect(res.payment.reference).toBe("UZ-20260928-42");
  });

  it("pay() surfaces the server's 409 message as an ApiError", async () => {
    respondWith(409, {
      message: "Энэ аяны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
    });
    const { companyApi } = await import("./api");

    await expect(companyApi.pay(42)).rejects.toMatchObject({
      name: "ApiError",
      status: 409,
      message: "Энэ аяны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
    });
  });

  it("payments() GETs /company/payments", async () => {
    respondWith(200, [{ id: 1, reference: "UZ-20260928-42", amount: 1_000_000 }]);
    const { companyApi } = await import("./api");

    const res = await companyApi.payments();

    expect(calls[0].url).toMatch(/\/company\/payments$/);
    expect(calls[0].init.method).toBe("GET");
    expect(res[0].reference).toBe("UZ-20260928-42");
  });

  it("setStatus() PATCHes the status as a query parameter", async () => {
    respondWith(200, { id: 5, status: "PAUSED" });
    const { companyApi } = await import("./api");

    await companyApi.setStatus(5, "PAUSED");

    expect(calls[0].url).toMatch(/\/company\/campaigns\/5\/status\?status=PAUSED$/);
    expect(calls[0].init.method).toBe("PATCH");
  });
});
