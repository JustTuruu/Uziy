import { afterEach, describe, expect, it, vi } from "vitest";
import { DEVICE_TOKEN_KEY, isTwoStep } from "@uziy/ui";
import { adminApi, auth, authApi, companiesApi } from "./api";

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

const twoStep = {
  verificationId: "c0ffee00-0000-0000-0000-000000000001",
  phoneNumber: "•••• 1122",
  role: "ADMIN",
  shortcode: "144773",
  smsText: "482916",
  smsUri: "sms:144773?body=482916",
  displayInstruction: "SMS илгээнэ үү",
  expiresAt: "2026-10-22T04:05:00Z",
};

describe("authApi console login", () => {
  it("returns the 202 SMS step from login", async () => {
    mockFetch(202, { twoStep });
    const res = await authApi.login({ phoneNumber: "99001122", password: "x" });
    expect(isTwoStep(res)).toBe(true);
  });

  it("sends the device token with the login, without a bearer token", async () => {
    window.localStorage.setItem("uziy.jwt", "old");
    const calls = mockFetch(200, { token: "t", user: {} });
    await authApi.login({ phoneNumber: "99001122", password: "x", deviceToken: "device-1" });
    expect(JSON.parse(String(calls[0].init.body))).toEqual({
      phoneNumber: "99001122",
      password: "x",
      deviceToken: "device-1",
    });
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBeUndefined();
  });

  it("polls the phone check without a token", async () => {
    window.localStorage.setItem("uziy.jwt", "old");
    const calls = mockFetch(200, { verificationId: twoStep.verificationId, status: "PENDING", expiresAt: twoStep.expiresAt });
    await authApi.phoneCheck(twoStep.verificationId);
    expect(calls[0].url).toMatch(/\/auth\/phone-verifications\/c0ffee00-0000-0000-0000-000000000001$/);
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBeUndefined();
  });

  it("finishes the login at /auth/login/verify with the phone and the check", async () => {
    const calls = mockFetch(200, { token: "jwt", user: {}, deviceToken: "d", deviceTrustedUntil: "x" });
    const res = await authApi.verify({ phoneNumber: "99001122", verificationId: twoStep.verificationId });
    expect(res.deviceToken).toBe("d");
    expect(calls[0].url).toMatch(/\/auth\/login\/verify$/);
    expect(calls[0].init.method).toBe("POST");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({
      phoneNumber: "99001122",
      verificationId: twoStep.verificationId,
    });
  });

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
