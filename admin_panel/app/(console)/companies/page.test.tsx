import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError, companiesApi, type CompanyAccount } from "@/lib/api";
import CompaniesPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

function company(id: number, name: string, campaignCount = 0): CompanyAccount {
  return {
    id,
    companyName: name,
    phoneNumber: `8811223${id}`,
    createdAt: "2026-10-20T04:00:00Z",
    campaignCount,
  };
}

async function fillAndSubmit(name: string, phone: string, password: string) {
  const user = userEvent.setup();
  await user.type(screen.getByLabelText("Компанийн нэр"), name);
  await user.type(screen.getByLabelText("Утасны дугаар"), phone);
  await user.type(screen.getByLabelText(/^Түр нууц үг/), password);
  await user.click(screen.getByRole("button", { name: "Компани нэмэх" }));
}

describe("Companies page", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    router.replace.mockReset();
    window.localStorage.setItem("uziy.jwt", "admin-jwt");
  });
  afterEach(() => window.localStorage.clear());

  it("lists every company with its survey count", async () => {
    vi.spyOn(companiesApi, "list").mockResolvedValue([
      company(1, "MobiCom", 3),
      company(2, "UniTel"),
    ]);
    render(<CompaniesPage />);
    expect(await screen.findByText("Бүх компани (2)")).toBeTruthy();
    const row = screen.getByRole("link", { name: "MobiCom" }).closest("tr")!;
    expect(within(row).getByText("3")).toBeTruthy();
    expect(screen.getByRole("link", { name: "UniTel" })).toHaveAttribute("href", "/companies/2");
  });

  it("creates a company and shows the temporary password once", async () => {
    vi.spyOn(companiesApi, "list").mockResolvedValue([]);
    const create = vi
      .spyOn(companiesApi, "create")
      .mockResolvedValue(company(5, "Голомт Банк"));
    render(<CompaniesPage />);
    await screen.findByText("Бүх компани (0)");

    await fillAndSubmit(" Голомт Банк ", "88112235", "temp-pass1");

    await waitFor(() =>
      expect(create).toHaveBeenCalledWith({
        companyName: "Голомт Банк",
        phoneNumber: "88112235",
        password: "temp-pass1",
      }),
    );
    expect(await screen.findByText("«Голомт Банк» компанийн данс үүслээ")).toBeTruthy();
    expect(screen.getByTestId("handover-password").textContent).toBe("temp-pass1");
    expect(screen.getByText("Бүх компани (1)")).toBeTruthy();
    expect(screen.getByLabelText(/^Түр нууц үг/)).toHaveValue("");

    await userEvent.click(screen.getByRole("button", { name: "Ойлголоо" }));
    expect(screen.queryByTestId("handover-password")).toBeNull();
  });

  it("checks the form before sending", async () => {
    vi.spyOn(companiesApi, "list").mockResolvedValue([]);
    const create = vi.spyOn(companiesApi, "create");
    render(<CompaniesPage />);
    await screen.findByText("Бүх компани (0)");

    await fillAndSubmit("MobiCom", "8811", "temp-pass1");

    expect(await screen.findByText("Утасны дугаар 8 оронтой тоо байх ёстой")).toBeTruthy();
    expect(create).not.toHaveBeenCalled();
  });

  it("shows the backend's words for a phone that is taken", async () => {
    vi.spyOn(companiesApi, "list").mockResolvedValue([]);
    vi.spyOn(companiesApi, "create").mockRejectedValue(
      new ApiError("Энэ утасны дугаар өөр бүртгэлд ашиглагдаж байна", 409, null),
    );
    render(<CompaniesPage />);
    await screen.findByText("Бүх компани (0)");

    await fillAndSubmit("MobiCom", "88112233", "temp-pass1");

    expect(
      await screen.findByText("Энэ утасны дугаар өөр бүртгэлд ашиглагдаж байна"),
    ).toBeTruthy();
    expect(screen.queryByTestId("handover-password")).toBeNull();
  });

  it("can suggest a temporary password", async () => {
    vi.spyOn(companiesApi, "list").mockResolvedValue([]);
    render(<CompaniesPage />);
    await userEvent.click(screen.getByRole("button", { name: "Нууц үг үүсгэх" }));
    expect((screen.getByLabelText(/^Түр нууц үг/) as HTMLInputElement).value).toHaveLength(10);
  });

  it("sends a signed-out admin to the login page", async () => {
    vi.spyOn(companiesApi, "list").mockRejectedValue(new ApiError("x", 401, null));
    render(<CompaniesPage />);
    await waitFor(() => expect(router.replace).toHaveBeenCalledWith("/login"));
  });
});
