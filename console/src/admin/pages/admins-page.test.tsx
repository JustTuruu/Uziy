import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, adminsApi, type AdminAccount } from "@admin/lib/api";
import AdminsPage from "./admins-page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("@shared/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@shared/navigation")>()),
  useRouter: () => router,
}));

function admin(id: number): AdminAccount {
  return { id, phoneNumber: `8811223${id}`, createdAt: "2026-10-20T04:00:00Z" };
}

async function fillAndSubmit(phone: string, password: string) {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText("Утасны дугаар"), phone);
  await user.type(screen.getByLabelText(/^Түр нууц үг/), password);
  await user.click(screen.getByRole("button", { name: "Админ нэмэх" }));
}

describe("Admins page", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.replace.mockReset();
    window.localStorage.setItem("uziy.jwt", "admin-jwt");
    window.localStorage.setItem(
      "uziy.user",
      JSON.stringify({ id: 1, phoneNumber: "88112231", role: "ADMIN" }),
    );
  });
  afterEach(() => window.localStorage.clear());

  it("lists every admin and marks the signed-in one", async () => {
    vi.spyOn(adminsApi, "list").mockResolvedValue([admin(2), admin(1)]);
    render(<AdminsPage />);
    expect(await screen.findByText("Бүх админ (2)")).toBeTruthy();
    const rows = screen.getAllByRole("row").slice(1);
    expect(within(rows[0]).queryByText("Та")).toBeNull();
    expect(within(rows[1]).getByText("Та")).toBeTruthy();
  });

  it("creates an admin and shows the temporary password once", async () => {
    vi.spyOn(adminsApi, "list").mockResolvedValue([admin(1)]);
    const create = vi.spyOn(adminsApi, "create").mockResolvedValue(admin(5));
    render(<AdminsPage />);
    await screen.findByText("Бүх админ (1)");

    await fillAndSubmit("88112235", "temp-pass1");

    await waitFor(() =>
      expect(create).toHaveBeenCalledWith({ phoneNumber: "88112235", password: "temp-pass1" }),
    );
    expect(await screen.findByText("Админы данс үүслээ")).toBeTruthy();
    expect(screen.getByTestId("handover-password").textContent).toBe("temp-pass1");
    expect(screen.getByText("Бүх админ (2)")).toBeTruthy();
    expect(screen.getByLabelText("Утасны дугаар")).toHaveValue("");

    await userEvent.click(screen.getByRole("button", { name: "Ойлголоо" }));
    expect(screen.queryByTestId("handover-password")).toBeNull();
  });

  it("checks the form before sending", async () => {
    vi.spyOn(adminsApi, "list").mockResolvedValue([]);
    const create = vi.spyOn(adminsApi, "create");
    render(<AdminsPage />);
    await screen.findByText("Бүх админ (0)");

    await fillAndSubmit("88112233", "12345");

    expect(await screen.findByText("Нууц үг 6–100 тэмдэгт байх ёстой")).toBeTruthy();
    expect(create).not.toHaveBeenCalled();
  });

  it("shows the backend's words for a phone that is taken", async () => {
    vi.spyOn(adminsApi, "list").mockResolvedValue([]);
    vi.spyOn(adminsApi, "create").mockRejectedValue(
      new ApiError("Энэ утасны дугаар өөр бүртгэлд ашиглагдаж байна", 409, null),
    );
    render(<AdminsPage />);
    await screen.findByText("Бүх админ (0)");

    await fillAndSubmit("88112233", "temp-pass1");

    expect(await screen.findByText("Энэ утасны дугаар өөр бүртгэлд ашиглагдаж байна")).toBeTruthy();
    expect(screen.queryByTestId("handover-password")).toBeNull();
  });

  it("sends a signed-out admin to the login page", async () => {
    vi.spyOn(adminsApi, "list").mockRejectedValue(new ApiError("x", 403, null));
    render(<AdminsPage />);
    await waitFor(() => expect(router.replace).toHaveBeenCalledWith("/login"));
  });
});
