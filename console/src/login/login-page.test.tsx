import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { CONSOLE_LOGIN_POLL_MS, DEVICE_TOKEN_KEY } from "@uziy/ui";
import { ApiError, auth } from "@shared/api/http";
import { authApi } from "@shared/api/auth-api";
import type { Me } from "@shared/api/types";
import LoginPage from "./login-page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("@shared/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@shared/navigation")>()),
  useRouter: () => router,
}));

function me(role: Me["role"]): Me {
  return {
    id: 1,
    phoneNumber: "99112233",
    role,
    gender: null,
    age: null,
    city: null,
    balance: 0,
    isVerified: true,
    companyName: "MobiCom",
    district: null,
    lastName: null,
    firstName: null,
  };
}

const twoStep = {
  verificationId: "c0ffee00-0000-0000-0000-000000000002",
  phoneNumber: "•••• 2233",
  role: "COMPANY",
  shortcode: "144773",
  smsText: "482916",
  smsUri: "sms:144773?body=482916",
  displayInstruction: 'Та өөрийн 99112233 дугаараас 144773 дугаарт "482916" гэж SMS илгээнэ үү.',
  expiresAt: "2999-01-01T00:00:00Z",
};

function checkSays(status: "PENDING" | "VERIFIED" | "EXPIRED") {
  return { verificationId: twoStep.verificationId, status, expiresAt: twoStep.expiresAt };
}

async function nextPoll() {
  await act(async () => {
    await vi.advanceTimersByTimeAsync(CONSOLE_LOGIN_POLL_MS);
  });
}

async function submitForm() {
  const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
  await user.type(screen.getByLabelText("Утасны дугаар"), "99112233");
  await user.type(screen.getByLabelText("Нууц үг"), "secret1");
  await user.click(screen.getByRole("button", { name: "Нэвтрэх" }));
}

describe("Company login", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.push.mockReset();
    window.localStorage.clear();
    vi.useFakeTimers({ shouldAdvanceTime: true });
  });
  afterEach(() => {
    vi.useRealTimers();
    window.localStorage.clear();
  });

  it("has no role picker", () => {
    render(<LoginPage />);
    expect(screen.queryByText("Супер Админ")).toBeNull();
  });

  it("signs in a COMPANY from a remembered browser at once, sending its device token", async () => {
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-1");
    const login = vi.spyOn(authApi, "login").mockResolvedValue({
      token: "jwt-1",
      user: me("COMPANY"),
    });
    render(<LoginPage />);
    await submitForm();
    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/"));
    expect(login).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      password: "secret1",
      deviceToken: "device-1",
    });
    expect(auth.getToken()).toBe("jwt-1");
    expect(screen.queryByText("Утсаа баталгаажуулах")).toBeNull();
  });

  it("on a new browser shows the SMS to send, not the dashboard", async () => {
    const login = vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утсаа баталгаажуулах")).toBeTruthy();
    expect(login).toHaveBeenCalledWith({ phoneNumber: "99112233", password: "secret1" });
    expect(screen.getByText("144773")).toBeTruthy();
    expect(screen.getByText("482916")).toBeTruthy();
    expect(screen.getByText(twoStep.displayInstruction)).toBeTruthy();
    expect(screen.getByText("Энэ хөтөч 30 хоног танигдана.")).toBeTruthy();
    expect(router.push).not.toHaveBeenCalled();
    expect(auth.getToken()).toBeNull();
  });

  it("after the SMS signs in, stores the new device token and keeps it on logout", async () => {
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-old");
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    vi.spyOn(authApi, "phoneCheck")
      .mockResolvedValueOnce(checkSays("PENDING"))
      .mockResolvedValue(checkSays("VERIFIED"));
    const verify = vi.spyOn(authApi, "verify").mockResolvedValue({
      token: "jwt-company",
      user: me("COMPANY"),
      deviceToken: "device-new",
      deviceTrustedUntil: "2026-11-21T04:00:00Z",
    });
    render(<LoginPage />);
    await submitForm();
    await screen.findByText("Утсаа баталгаажуулах");

    await nextPoll();
    await nextPoll();

    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/"));
    expect(verify).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      verificationId: twoStep.verificationId,
    });
    expect(auth.getToken()).toBe("jwt-company");
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-new");

    auth.clear();
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-new");
  });

  it("offers a new code when the check expired", async () => {
    const login = vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    vi.spyOn(authApi, "phoneCheck").mockResolvedValue(checkSays("EXPIRED"));
    render(<LoginPage />);
    await submitForm();
    await screen.findByText("Утсаа баталгаажуулах");

    await nextPoll();
    expect(await screen.findByText("Кодын хугацаа дууслаа")).toBeTruthy();

    const user = userEvent.setup({ advanceTimers: vi.advanceTimersByTime });
    await user.click(screen.getByRole("button", { name: "Шинэ код авах" }));
    await waitFor(() => expect(login).toHaveBeenCalledTimes(2));
    expect(await screen.findByText("Шинэ код үүслээ. Хуучин кодыг бүү илгээгээрэй.")).toBeTruthy();
  });

  it("says a wrong password in Mongolian and opens no SMS step", async () => {
    vi.spyOn(authApi, "login").mockRejectedValue(new ApiError("x", 401, null));
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утас эсвэл нууц үг буруу байна")).toBeTruthy();
    expect(screen.queryByText("Утсаа баталгаажуулах")).toBeNull();
  });

  it("rejects a signed-in VIEWER account without storing a token", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ token: "jwt-2", user: me("VIEWER") });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Энэ дансаар самбарт нэвтрэх эрхгүй байна")).toBeTruthy();
    expect(router.push).not.toHaveBeenCalled();
    expect(auth.getToken()).toBeNull();
  });

  it("signs an ADMIN in here too and opens the admin area", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ token: "admin-jwt", user: me("ADMIN") });
    render(<LoginPage />);
    await submitForm();
    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/admin"));
    expect(auth.getToken()).toBe("admin-jwt");
    expect(auth.getUser()?.role).toBe("ADMIN");
  });

  it("gives an admin the SMS step too, then opens the admin area", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep: { ...twoStep, role: "ADMIN" } });
    vi.spyOn(authApi, "phoneCheck").mockResolvedValue(checkSays("VERIFIED"));
    vi.spyOn(authApi, "verify").mockResolvedValue({
      token: "admin-jwt",
      user: me("ADMIN"),
      deviceToken: "device-9",
      deviceTrustedUntil: "2026-11-21T00:00:00Z",
    });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утсаа баталгаажуулах")).toBeTruthy();
    await nextPoll();
    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/admin"));
    expect(auth.getToken()).toBe("admin-jwt");
  });

  it("says accounts are made by Uziy and how to ask for one, with no sign-up", () => {
    render(<LoginPage />);
    expect(screen.getByText(/Компанийн дансыг Uziy үүсгэж өгнө/)).toBeTruthy();
    expect(screen.getByRole("link", { name: "sales@uziy.mn" })).toHaveAttribute(
      "href",
      "mailto:sales@uziy.mn",
    );
    expect(screen.queryByText(/Бүртгүүлэх/)).toBeNull();
  });
});
