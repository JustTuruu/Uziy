import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DEVICE_TOKEN_KEY, isTwoStep } from "@uziy/ui";
import { aMe } from "../test/fixtures";
import { authApi } from "./auth-api";
import { ApiError, apiFetch, auth, GENERIC_ERROR_MESSAGE, NETWORK_ERROR_MESSAGE } from "./http";

describe("auth (localStorage helpers)", () => {
  beforeEach(() => window.localStorage.clear());

  it("round-trips a token", () => {
    auth.setToken("abc.def.ghi");
    expect(auth.getToken()).toBe("abc.def.ghi");
  });

  it("round-trips the current user", () => {
    const me = aMe({ phoneNumber: "88112233", role: "ADMIN", companyName: null });
    auth.setUser(me);
    expect(auth.getUser()).toEqual(me);
  });

  it("clear() wipes both token and user", () => {
    auth.setToken("x");
    auth.setUser(aMe({ role: "ADMIN" }));
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

    const { platformSettingsApi } = await import("./platform-settings");
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

