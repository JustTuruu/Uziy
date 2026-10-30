import { afterEach, describe, expect, it, vi } from "vitest";
import { DEVICE_TOKEN_KEY } from "@uziy/ui";
import { adminApi, auth, companiesApi } from "./api";

const originalFetch = globalThis.fetch;

function mockFetch(status: number, body: unknown) {
  const calls: { url: string; init: RequestInit }[] = [];
  globalThis.fetch = vi.fn(async (url: RequestInfo | URL, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return new Response(body === null ? null : JSON.stringify(body), { status });
  }) as typeof fetch;
  return calls;
}

afterEach(() => {
  globalThis.fetch = originalFetch;
  window.localStorage.clear();
});


describe("auth", () => {
  it("keeps the browser's device token when signing out", () => {
    auth.setToken("jwt");
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-1");
    auth.clear();
    expect(auth.getToken()).toBeNull();
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-1");
  });
});

describe("adminApi.forgetTrustedDevices", () => {
  it("POSTs the forget action for the account with the admin's token", async () => {
    window.localStorage.setItem("uziy.jwt", "admin-jwt");
    const calls = mockFetch(204, null);
    await adminApi.forgetTrustedDevices(12);
    expect(calls[0].url).toMatch(/\/admin\/users\/12\/trusted-devices\/forget$/);
    expect(calls[0].init.method).toBe("POST");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer admin-jwt");
  });
});

describe("companiesApi", () => {
  it("creates a company with the admin's token", async () => {
    window.localStorage.setItem("uziy.jwt", "admin-jwt");
    const calls = mockFetch(201, { id: 5 });
    await companiesApi.create({ companyName: "MobiCom", phoneNumber: "88112233", password: "temp-pass1" });
    expect(calls[0].url).toMatch(/\/admin\/companies$/);
    expect(calls[0].init.method).toBe("POST");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer admin-jwt");
  });

  it("lists companies", async () => {
    const calls = mockFetch(200, []);
    expect(await companiesApi.list()).toEqual([]);
    expect(calls[0].url).toMatch(/\/admin\/companies$/);
  });
});
