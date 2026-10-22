import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  ApiError,
  apiFetch,
  auth,
  authApi,
  GENERIC_ERROR_MESSAGE,
  NETWORK_ERROR_MESSAGE,
} from "./api";

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

describe("authApi.redeemHandoff", () => {
  const originalFetch = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = originalFetch;
    window.localStorage.clear();
  });

  it("POSTs the code to /auth/session-handoffs/redeem without any token", async () => {
    auth.setToken("stale");
    let captured: RequestInit | undefined;
    let capturedUrl: RequestInfo | URL | undefined;
    globalThis.fetch = vi.fn(async (url, init) => {
      capturedUrl = url;
      captured = init ?? {};
      return new Response(JSON.stringify({ token: "t", user: { id: 1 } }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }) as typeof fetch;

    const res = await authApi.redeemHandoff("one-time");

    expect(String(capturedUrl)).toMatch(/\/auth\/session-handoffs\/redeem$/);
    expect(captured!.method).toBe("POST");
    expect(JSON.parse(String(captured!.body))).toEqual({ code: "one-time" });
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
