import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  apiFetch,
  auth,
  authApi,
  GENERIC_ERROR_MESSAGE,
  NETWORK_ERROR_MESSAGE,
} from "./api";
import { DEVICE_TOKEN_KEY, isTwoStep } from "@uziy/ui";

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

  it("clear() keeps the browser's device token, so the next login skips the SMS", () => {
    auth.setToken("x");
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-1");
    auth.clear();
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-1");
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

  it("a body without a message gets the Mongolian generic sentence, not the status text", async () => {
    mockFetch(403, { status: 403, error: "Forbidden" });
    const err = (await apiFetch("/x").catch((e) => e)) as ApiError;
    expect(err.status).toBe(403);
    expect(err.message).toBe(GENERIC_ERROR_MESSAGE);
  });

  it("an unreachable server is a Mongolian ApiError with status 0, not the browser's 'Failed to fetch'", async () => {
    globalThis.fetch = vi.fn(async () => {
      throw new TypeError("Failed to fetch");
    }) as typeof fetch;
    const err = (await apiFetch("/x").catch((e) => e)) as ApiError;
    expect(err).toBeInstanceOf(ApiError);
    expect(err.status).toBe(0);
    expect(err.message).toBe(NETWORK_ERROR_MESSAGE);
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

    const res = await authApi.login({
      phoneNumber: "88112233",
      password: "password",
      deviceToken: "device-1",
    });

    expect(String(capturedUrl)).toContain("/auth/login");
    expect(captured!.method).toBe("POST");
    expect((captured!.headers as Record<string, string>).Authorization).toBeUndefined();
    expect(JSON.parse(String(captured!.body))).toEqual({
      phoneNumber: "88112233",
      password: "password",
      deviceToken: "device-1",
    });
    expect(isTwoStep(res)).toBe(false);
  });

  it("polls the phone check and finishes the SMS step at /auth/login/verify, without a token", async () => {
    auth.setToken("old");
    const urls: string[] = [];
    const inits: RequestInit[] = [];
    globalThis.fetch = vi.fn(async (url, init) => {
      urls.push(String(url));
      inits.push(init ?? {});
      return new Response(JSON.stringify({}), { status: 200 });
    }) as typeof fetch;

    await authApi.phoneCheck("c0ffee00-0000-0000-0000-000000000001");
    await authApi.verify({ phoneNumber: "88112233", verificationId: "c0ffee00-0000-0000-0000-000000000001" });

    expect(urls[0]).toMatch(/\/auth\/phone-verifications\/c0ffee00-0000-0000-0000-000000000001$/);
    expect(urls[1]).toMatch(/\/auth\/login\/verify$/);
    expect(inits[1].method).toBe("POST");
    for (const init of inits) {
      expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
    }
  });
});

describe("platformSettingsApi", () => {
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
      message: "Энэ судалгааны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
    });
    const { companyApi } = await import("./api");

    await expect(companyApi.pay(42)).rejects.toMatchObject({
      name: "ApiError",
      status: 409,
      message: "Энэ судалгааны төлбөр аль хэдийн төлөгдсөн эсвэл төлөх боломжгүй",
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
