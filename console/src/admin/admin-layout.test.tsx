import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, auth, type AdminStats, type Me } from "@admin/lib/api";
import AdminLayout from "./admin-layout";

let path = "/";
vi.mock("@shared/navigation", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@shared/navigation")>()),
  usePathname: () => path,
}));

const admin: Me = {
  id: 1,
  phoneNumber: "99001122",
  role: "ADMIN",
  gender: null,
  age: null,
  city: null,
  balance: 0,
  isVerified: true,
  companyName: null,
  district: null,
  lastName: null,
  firstName: null,
};

const stats = (
  pendingPayouts: number,
  pendingCampaigns: number,
): AdminStats => ({
  totalUsers: 0,
  totalCampaigns: 0,
  activeCampaigns: 0,
  pendingCampaigns,
  pendingPayouts,
  awaitingPaymentCampaigns: 0,
  commissionPercent: 30,
  commissionRate: 0.3,
});

describe("Admin console layout", () => {
  beforeEach(() => {
    path = "/admin";
    window.localStorage.clear();
    vi.spyOn(adminApi, "stats").mockResolvedValue(stats(0, 0));
  });
  afterEach(() => window.localStorage.clear());

  it("groups the navigation under section headings", () => {
    render(<AdminLayout>x</AdminLayout>);
    for (const h of ["Ерөнхий", "Хяналт", "Тохиргоо"]) {
      expect(screen.getByText(h)).toBeTruthy();
    }
  });

  it("links to the company accounts page", () => {
    render(<AdminLayout>x</AdminLayout>);
    expect(screen.getByRole("link", { name: "Компаниуд" }).getAttribute("href")).toBe(
      "/admin/companies",
    );
  });

  it("links to the admin accounts page under settings", () => {
    render(<AdminLayout>x</AdminLayout>);
    expect(screen.getByRole("link", { name: "Админууд" }).getAttribute("href")).toBe("/admin/admins");
  });

  it("marks the current route and shows it in the breadcrumb", () => {
    path = "/admin/users";
    render(<AdminLayout>x</AdminLayout>);
    const link = screen.getByRole("link", { name: "Хэрэглэгчид" });
    expect(link.getAttribute("aria-current")).toBe("page");
    expect(
      screen.getByRole("navigation", { name: "Breadcrumb" }).textContent,
    ).toContain("Хэрэглэгчид");
  });

  it("marks the dashboard only on its own page, not on every admin page", () => {
    path = "/admin/payouts";
    render(<AdminLayout>x</AdminLayout>);
    expect(screen.getByRole("link", { name: "Хяналтын самбар" }).getAttribute("aria-current")).toBeNull();
  });

  it("adds a detail crumb on nested routes", () => {
    path = "/admin/campaigns/4";
    render(<AdminLayout>x</AdminLayout>);
    expect(
      screen.getByRole("navigation", { name: "Breadcrumb" }).textContent,
    ).toContain("Дэлгэрэнгүй");
  });

  it("shows the signed-in admin's phone, not a hardcoded one", async () => {
    auth.setUser(admin);
    render(<AdminLayout>x</AdminLayout>);
    expect(await screen.findByText("+976 9900 1122")).toBeTruthy();
  });

  it("clears the session when logging out", async () => {
    auth.setToken("t");
    auth.setUser(admin);
    render(<AdminLayout>x</AdminLayout>);
    screen.getByRole("link", { name: "Гарах" }).click();
    expect(auth.getToken()).toBeNull();
  });

  it("shows the live pending counts as sidebar badges", async () => {
    vi.spyOn(adminApi, "stats").mockResolvedValue(stats(3, 5));
    render(<AdminLayout>x</AdminLayout>);
    expect(
      await screen.findByRole("link", { name: /Мөнгө татах\s*3/ }),
    ).toBeTruthy();
    expect(screen.getByRole("link", { name: /Судалгаа\s*5/ })).toBeTruthy();
    expect(screen.getByRole("img", { name: "8 хүлээгдэж буй" })).toBeTruthy();
  });

  it("shows no badges when the stats request fails", async () => {
    vi.spyOn(adminApi, "stats").mockRejectedValue(new Error("down"));
    render(<AdminLayout>x</AdminLayout>);
    // Exact name: with a badge the accessible name would be "Мөнгө татах 3".
    expect(
      await screen.findByRole("link", { name: "Мөнгө татах" }),
    ).toBeTruthy();
  });
});
