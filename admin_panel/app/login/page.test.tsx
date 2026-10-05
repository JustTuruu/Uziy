import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth, authApi, type Me } from "@/lib/api";
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

async function submitForm() {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText("Утасны дугаар"), "99112233");
  await user.type(screen.getByLabelText("Нууц үг"), "secret1");
  await user.click(screen.getByRole("button", { name: "Нэвтрэх" }));
}

describe("Super admin login", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.push.mockReset();
    window.localStorage.clear();
  });
  afterEach(() => window.localStorage.clear());

  it("has no role picker", () => {
    render(<LoginPage />);
    expect(screen.queryByText("Компани")).toBeNull();
  });

  it("signs in a ADMIN and lands on the dashboard root", async () => {
    vi.spyOn(authApi, "login").mockResolvedValue({
      token: "jwt-1",
      user: me("ADMIN"),
    });
    render(<LoginPage />);
    await submitForm();
    await waitFor(() => expect(router.push).toHaveBeenCalledWith("/"));
    expect(auth.getToken()).toBe("jwt-1");
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
