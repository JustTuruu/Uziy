import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, auth, authApi, type Me } from "@/lib/api";
import { CONSOLE_LOGIN_POLL_MS, DEVICE_TOKEN_KEY } from "@uziy/ui";
import LoginPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

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
    companyName: null,
  };
}

const twoStep = {
  verificationId: "c0ffee00-0000-0000-0000-000000000001",
  phoneNumber: "•••• 2233",
  role: "ADMIN",
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

describe("Super admin login", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.push.mockReset();
    window.localStorage.clear();
    // Real time keeps flowing (user-event, waitFor); the poll interval is stepped by hand.
    vi.useFakeTimers({ shouldAdvanceTime: true });
  });
  afterEach(() => {
    vi.useRealTimers();
    window.localStorage.clear();
  });

  it("has no role picker", () => {
    render(<LoginPage />);
    expect(screen.queryByText("Компани")).toBeNull();
  });

  it("after the password shows the SMS to send, not the dashboard", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утсаа баталгаажуулах")).toBeTruthy();
    expect(screen.getByText("144773")).toBeTruthy();
    expect(screen.getByText("482916")).toBeTruthy();
    expect(screen.getByText(twoStep.displayInstruction)).toBeTruthy();
    expect(screen.getByRole("link", { name: "SMS илгээх" })).toHaveAttribute(
      "href",
      twoStep.smsUri,
    );
    expect(router.push).not.toHaveBeenCalled();
    expect(auth.getToken()).toBeNull();
  });

  it("polls the check, signs the admin in once the SMS arrived and remembers the browser", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    const check = vi
      .spyOn(authApi, "phoneCheck")
      .mockResolvedValueOnce(checkSays("PENDING"))
      .mockResolvedValue(checkSays("VERIFIED"));
    const verify = vi.spyOn(authApi, "verify").mockResolvedValue({
      token: "jwt-admin",
      user: me("ADMIN"),
      deviceToken: "device-new",
      deviceTrustedUntil: "2026-11-21T04:00:00Z",
    });
    render(<LoginPage />);
    await submitForm();
    await screen.findByText("Утсаа баталгаажуулах");

    await nextPoll();
    expect(verify).not.toHaveBeenCalled();
    await nextPoll();

    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/"));
    expect(check).toHaveBeenCalledWith(twoStep.verificationId);
    expect(verify).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      verificationId: twoStep.verificationId,
    });
    expect(auth.getToken()).toBe("jwt-admin");
    expect(window.localStorage.getItem(DEVICE_TOKEN_KEY)).toBe("device-new");
    expect(screen.getByText("Энэ хөтөч 30 хоног танигдана.")).toBeTruthy();
  });

  it("sends the remembered browser's token and is signed in without the SMS step", async () => {
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-1");
    const login = vi
      .spyOn(authApi, "login")
      .mockResolvedValue({ token: "jwt-admin", user: me("ADMIN") });
    render(<LoginPage />);
    await submitForm();
    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/"));
    expect(login).toHaveBeenCalledWith({
      phoneNumber: "99112233",
      password: "secret1",
      deviceToken: "device-1",
    });
    expect(screen.queryByText("Утсаа баталгаажуулах")).toBeNull();
    expect(auth.getToken()).toBe("jwt-admin");
  });

  it("asks for the SMS again when the stored device token is not trusted any more", async () => {
    window.localStorage.setItem(DEVICE_TOKEN_KEY, "device-old");
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утсаа баталгаажуулах")).toBeTruthy();
    expect(auth.getToken()).toBeNull();
  });

  it("turns away a company account at its SMS step without showing it", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep: { ...twoStep, role: "COMPANY" } });
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Энэ данс админ эрхгүй байна")).toBeTruthy();
    expect(screen.queryByText("Утсаа баталгаажуулах")).toBeNull();
  });

  it("offers a new code when the check expired, and asks for it with the same password", async () => {
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
    expect(login).toHaveBeenLastCalledWith({ phoneNumber: "99112233", password: "secret1" });
    expect(await screen.findByText("Шинэ код үүслээ. Хуучин кодыг бүү илгээгээрэй.")).toBeTruthy();
  });

  it("shows the backend's words when the last step is refused", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({ twoStep });
    vi.spyOn(authApi, "phoneCheck").mockResolvedValue(checkSays("VERIFIED"));
    vi.spyOn(authApi, "verify").mockRejectedValue(
      new ApiError("Утасны дугаар баталгаажаагүй байна. Дахин оролдоно уу", 400, null),
    );
    render(<LoginPage />);
    await submitForm();
    await screen.findByText("Утсаа баталгаажуулах");

    await nextPoll();

    expect(
      await screen.findByText("Утасны дугаар баталгаажаагүй байна. Дахин оролдоно уу"),
    ).toBeTruthy();
    expect(screen.getByRole("button", { name: "Шинэ код авах" })).toBeTruthy();
    expect(router.push).not.toHaveBeenCalled();
  });

  it("says a wrong password in Mongolian and opens no SMS step", async () => {
    vi.spyOn(authApi, "login").mockRejectedValue(new ApiError("x", 401, null));
    render(<LoginPage />);
    await submitForm();
    expect(await screen.findByText("Утас эсвэл нууц үг буруу байна")).toBeTruthy();
    expect(screen.queryByText("Утсаа баталгаажуулах")).toBeNull();
  });

  it.each(["COMPANY", "VIEWER"] as const)(
    "rejects a %s account without storing a token",
    async (role) => {
      vi.spyOn(authApi, "login").mockResolvedValue({
        token: "jwt-2",
        user: me(role),
      });
      render(<LoginPage />);
      await submitForm();
      expect(await screen.findByText("Энэ данс админ эрхгүй байна")).toBeTruthy();
      expect(router.push).not.toHaveBeenCalled();
      expect(auth.getToken()).toBeNull();
    },
  );
});
