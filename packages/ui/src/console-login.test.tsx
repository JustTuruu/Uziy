import { act, renderHook, waitFor } from "@testing-library/react";
import type { FormEvent } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  CONSOLE_LOGIN_COPY,
  CONSOLE_LOGIN_POLL_MS,
  DEVICE_TOKEN_KEY,
  EXPIRY_GRACE_MS,
  deviceTokenStore,
  hasRunOut,
  isTwoStep,
  loginErrorMessage,
  sanitizePhone,
  useConsoleLogin,
  type ConsoleLoginApi,
  type ConsoleTwoStep,
  type UseConsoleLoginOptions,
} from "./console-login";

interface User {
  id: number;
  role: string;
}

const GENERIC = "Алдаа гарлаа. Дахин оролдоно уу";
const NOT_ROLE = "Энэ данс компани эрхгүй байна";

function twoStep(role = "COMPANY"): ConsoleTwoStep {
  return {
    verificationId: "c0ffee00-0000-0000-0000-000000000001",
    phoneNumber: "•••• 2233",
    role,
    shortcode: "144773",
    smsText: "482916",
    smsUri: "sms:144773?body=482916",
    displayInstruction: "SMS илгээнэ үү",
    expiresAt: "2999-01-01T00:00:00Z",
  };
}

function check(status: "PENDING" | "VERIFIED" | "EXPIRED") {
  return { verificationId: twoStep().verificationId, status, expiresAt: twoStep().expiresAt };
}

function fakeApi(): { [K in keyof ConsoleLoginApi<User>]: ReturnType<typeof vi.fn> } {
  return { login: vi.fn(), phoneCheck: vi.fn(), verify: vi.fn() };
}

const event = { preventDefault: () => {} } as FormEvent;

function setup(api = fakeApi(), overrides: Partial<UseConsoleLoginOptions<User>> = {}) {
  const onSignedIn = vi.fn();
  const view = renderHook(() =>
    useConsoleLogin<User>({
      api: api as unknown as ConsoleLoginApi<User>,
      roles: ["COMPANY"],
      notRoleMessage: NOT_ROLE,
      genericError: GENERIC,
      onSignedIn,
      ...overrides,
    }),
  );
  return { api, onSignedIn, view };
}

async function typeAndSubmit(view: ReturnType<typeof setup>["view"]) {
  act(() => {
    view.result.current.setPhone("9911-2233");
    view.result.current.setPassword("secret1");
  });
  await act(async () => {
    await view.result.current.submit(event);
  });
}

async function nextPoll() {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(CONSOLE_LOGIN_POLL_MS);
  });
}

describe("console login helpers", () => {
  it("tells the SMS step from a signed-in answer", () => {
    expect(isTwoStep({ twoStep: twoStep() })).toBe(true);
    expect(isTwoStep({ token: "t", user: { id: 1, role: "COMPANY" } })).toBe(false);
  });

  it("treats a check as run out only after the grace period", () => {
    const expiresAt = "2026-10-22T04:05:00Z";
    const deadline = Date.parse(expiresAt);
    expect(hasRunOut(expiresAt, deadline + EXPIRY_GRACE_MS)).toBe(false);
    expect(hasRunOut(expiresAt, deadline + EXPIRY_GRACE_MS + 1)).toBe(true);
    expect(hasRunOut("not a date", Date.now())).toBe(false);
  });

  it("keeps only the 8 national digits of a phone", () => {
    expect(sanitizePhone("9911 2233")).toBe("99112233");
    expect(sanitizePhone("9911-2233 44")).toBe("99112233");
  });

  it("words a wrong password plainly and otherwise shows the backend's message", () => {
    expect(loginErrorMessage({ status: 401, message: "x" }, GENERIC)).toBe(
      CONSOLE_LOGIN_COPY.wrongCredentials,
    );
    expect(loginErrorMessage({ status: 429, message: "Түр хүлээнэ үү" }, GENERIC)).toBe("Түр хүлээнэ үү");
    expect(loginErrorMessage({ status: 500, message: " " }, GENERIC)).toBe(GENERIC);
    expect(loginErrorMessage(new TypeError("Failed to fetch"), GENERIC)).toBe(GENERIC);
  });

  it("says how long the browser is remembered and names the masked phone", () => {
    expect(CONSOLE_LOGIN_COPY.deviceRemembered).toBe("Энэ хөтөч 30 хоног танигдана.");
    expect(CONSOLE_LOGIN_COPY.subtitle("•••• 1122")).toContain("•••• 1122");
  });
});

describe("deviceTokenStore", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  it("keeps the token under its own key", () => {
    deviceTokenStore.set("device-1");
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-1");
    expect(deviceTokenStore.get()).toBe("device-1");
  });

  it("works without storage (private mode): no token, no crash", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("blocked");
    });
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("blocked");
    });
    expect(deviceTokenStore.get()).toBeNull();
    expect(() => deviceTokenStore.set("x")).not.toThrow();
  });
});

describe("useConsoleLogin", () => {
  beforeEach(() => {
    window.localStorage.clear();
    vi.useFakeTimers({ shouldAdvanceTime: true });
  });
  afterEach(() => {
    vi.useRealTimers();
    window.localStorage.clear();
  });

  it("asks for a well-formed phone and password before calling the server", async () => {
    const { api, view } = setup();
    await act(async () => {
      await view.result.current.submit(event);
    });
    expect(view.result.current.error).toBe(CONSOLE_LOGIN_COPY.checkForm);
    expect(api.login).not.toHaveBeenCalled();
  });

  it("sends no device token from a browser that has none", async () => {
    const { api, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep() });
    await typeAndSubmit(view);
    expect(api.login).toHaveBeenCalledWith({ phoneNumber: "99112233", password: "secret1" });
  });

  it("sends the stored device token, and a remembered browser is signed in at once", async () => {
    deviceTokenStore.set("device-1");
    const { api, onSignedIn, view } = setup();
    const res = { token: "jwt", user: { id: 1, role: "COMPANY" } };
    api.login.mockResolvedValue(res);
    await typeAndSubmit(view);
    expect(api.login).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      password: "secret1",
      deviceToken: "device-1",
    });
    expect(onSignedIn).toHaveBeenCalledWith(res);
    expect(view.result.current.sms).toBeNull();
  });

  it("shows the SMS step on a 202, polls, and stores the new device token after the SMS", async () => {
    deviceTokenStore.set("stale-device");
    const { api, onSignedIn, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep() });
    api.phoneCheck.mockResolvedValueOnce(check("PENDING")).mockResolvedValue(check("VERIFIED"));
    api.verify.mockResolvedValue({
      token: "jwt",
      user: { id: 1, role: "COMPANY" },
      deviceToken: "device-2",
      deviceTrustedUntil: "2026-11-21T04:00:00Z",
    });
    await typeAndSubmit(view);
    expect(view.result.current.sms?.status).toBe("PENDING");

    await nextPoll();
    expect(api.verify).not.toHaveBeenCalled();
    await nextPoll();

    await waitFor(() => expect(onSignedIn).toHaveBeenCalledWith({ token: "jwt", user: { id: 1, role: "COMPANY" } }));
    expect(api.verify).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      verificationId: twoStep().verificationId,
    });
    expect(deviceTokenStore.get()).toBe("device-2");
  });

  it("turns away the other console's account before any SMS is shown", async () => {
    const { api, onSignedIn, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep("ADMIN") });
    await typeAndSubmit(view);
    expect(view.result.current.error).toBe(NOT_ROLE);
    expect(view.result.current.sms).toBeNull();
    expect(onSignedIn).not.toHaveBeenCalled();
  });

  it("admits every role it is given, before and after the SMS", async () => {
    const { api, onSignedIn, view } = setup(fakeApi(), { roles: ["COMPANY", "ADMIN"] });
    api.login.mockResolvedValue({ token: "jwt", user: { id: 1, role: "ADMIN" } });
    await typeAndSubmit(view);
    expect(view.result.current.error).toBeNull();
    expect(onSignedIn).toHaveBeenCalledWith({ token: "jwt", user: { id: 1, role: "ADMIN" } });

    api.login.mockResolvedValue({ twoStep: twoStep("ADMIN") });
    await typeAndSubmit(view);
    expect(view.result.current.sms?.challenge.role).toBe("ADMIN");
  });

  it("shows a failing onSignedIn as the form's error", async () => {
    const { api, view } = setup(fakeApi(), {
      onSignedIn: () => Promise.reject(new Error("boom")),
    });
    api.login.mockResolvedValue({ token: "jwt", user: { id: 1, role: "COMPANY" } });
    await typeAndSubmit(view);
    expect(view.result.current.error).toBe(GENERIC);
  });

  it("turns away a signed-in answer of another role", async () => {
    const { api, onSignedIn, view } = setup();
    api.login.mockResolvedValue({ token: "jwt", user: { id: 1, role: "VIEWER" } });
    await typeAndSubmit(view);
    expect(view.result.current.error).toBe(NOT_ROLE);
    expect(onSignedIn).not.toHaveBeenCalled();
  });

  it("marks the step expired and asks for a new code with the same password", async () => {
    const { api, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep() });
    api.phoneCheck.mockResolvedValue(check("EXPIRED"));
    await typeAndSubmit(view);

    await nextPoll();
    expect(view.result.current.sms?.status).toBe("EXPIRED");

    await act(async () => {
      await view.result.current.newCode();
    });
    expect(api.login).toHaveBeenCalledTimes(2);
    expect(view.result.current.notice).toBe(CONSOLE_LOGIN_COPY.newCodeReady);
    expect(view.result.current.sms?.status).toBe("PENDING");
  });

  it("keeps the old device token when the last step is refused", async () => {
    deviceTokenStore.set("device-1");
    const { api, onSignedIn, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep() });
    api.phoneCheck.mockResolvedValue(check("VERIFIED"));
    api.verify.mockRejectedValue({ status: 400, message: "Утасны дугаар баталгаажаагүй байна" });
    await typeAndSubmit(view);

    await nextPoll();

    await waitFor(() => expect(view.result.current.error).toBe("Утасны дугаар баталгаажаагүй байна"));
    expect(view.result.current.sms?.status).toBe("EXPIRED");
    expect(onSignedIn).not.toHaveBeenCalled();
    expect(deviceTokenStore.get()).toBe("device-1");
  });

  it("goes back to the password form and forgets the typed password", async () => {
    const { api, view } = setup();
    api.login.mockResolvedValue({ twoStep: twoStep() });
    await typeAndSubmit(view);

    act(() => view.result.current.back());

    expect(view.result.current.sms).toBeNull();
    expect(view.result.current.password).toBe("");
    expect(view.result.current.phone).toBe("99112233");
  });

  it("says a wrong password in plain words", async () => {
    const { api, view } = setup();
    api.login.mockRejectedValue({ status: 401, message: "x" });
    await typeAndSubmit(view);
    expect(view.result.current.error).toBe(CONSOLE_LOGIN_COPY.wrongCredentials);
  });
});
