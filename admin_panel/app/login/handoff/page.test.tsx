import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, auth, authApi, type Me } from "@/lib/api";
import { HANDOFF_EXPIRED, SIGN_IN_URL } from "@/lib/handoff";
import HandoffPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

const admin: Me = {
  id: 1,
  phoneNumber: "88112233",
  role: "ADMIN",
  gender: null,
  age: null,
  city: null,
  balance: 0,
  isVerified: true,
  companyName: null,
};

function openWith(hash: string) {
  window.history.replaceState(null, "", `/login/handoff${hash}`);
  render(<HandoffPage />);
}

describe("Admin handoff page", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.replace.mockReset();
    window.localStorage.clear();
  });
  afterEach(() => window.localStorage.clear());

  it("spends the code, removes it from the address bar and opens the dashboard", async () => {
    const redeem = vi.spyOn(authApi, "redeemHandoff").mockResolvedValue({ token: "admin-jwt", user: admin });

    openWith("#code=one-time");

    expect(window.location.hash).toBe("");
    expect(window.location.pathname).toBe("/login/handoff");
    await waitFor(() => expect(router.replace).toHaveBeenCalledWith("/"));
    expect(redeem).toHaveBeenCalledOnce();
    expect(redeem).toHaveBeenCalledWith("one-time");
    expect(auth.getToken()).toBe("admin-jwt");
  });

  it("says the link ran out and offers to sign in again", async () => {
    vi.spyOn(authApi, "redeemHandoff").mockRejectedValue(new ApiError(HANDOFF_EXPIRED, 400, null));

    openWith("#code=spent");

    expect(await screen.findByRole("alert")).toHaveTextContent(HANDOFF_EXPIRED);
    expect(screen.getByRole("link", { name: "Дахин нэвтрэх" })).toHaveAttribute("href", SIGN_IN_URL);
    expect(auth.getToken()).toBeNull();
    expect(router.replace).not.toHaveBeenCalled();
  });

  it("asks nothing of the server without a code", async () => {
    const redeem = vi.spyOn(authApi, "redeemHandoff");

    openWith("");

    expect(await screen.findByRole("alert")).toHaveTextContent(HANDOFF_EXPIRED);
    expect(redeem).not.toHaveBeenCalled();
  });
});
