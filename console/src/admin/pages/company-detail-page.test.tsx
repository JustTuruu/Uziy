import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, type AdminUser } from "@/lib/api";
import AdminCompanyDetailPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({
  useRouter: () => router,
  useParams: () => ({ id: "12" }),
}));

function account(role: AdminUser["role"]): AdminUser {
  return {
    id: 12,
    phoneNumber: "88112233",
    role,
    gender: null,
    age: null,
    city: null,
    balance: 0,
    isVerified: false,
    companyName: "MobiCom",
    createdAt: "2026-10-20T04:00:00Z",
  };
}

describe("Company detail page", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    window.localStorage.setItem("uziy.jwt", "admin-jwt");
    vi.spyOn(adminApi, "campaigns").mockResolvedValue([]);
  });
  afterEach(() => window.localStorage.clear());

  it("offers to forget the company's remembered browsers", async () => {
    vi.spyOn(adminApi, "user").mockResolvedValue(account("COMPANY"));
    render(<AdminCompanyDetailPage />);
    expect(await screen.findByRole("heading", { name: "MobiCom" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Төхөөрөмжүүдийг мартах" })).toBeTruthy();
  });

  it("does not offer it for an account that is not a company", async () => {
    vi.spyOn(adminApi, "user").mockResolvedValue(account("VIEWER"));
    render(<AdminCompanyDetailPage />);
    expect(await screen.findByText(/Энэ хэрэглэгч компани биш байна/)).toBeTruthy();
    expect(screen.queryByRole("button", { name: "Төхөөрөмжүүдийг мартах" })).toBeNull();
  });
});
