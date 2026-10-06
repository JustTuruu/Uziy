import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, auth, type AdminStats, type Me } from "@/lib/api";
import AdminLayout from "./layout";

let path = "/";
vi.mock("next/navigation", () => ({ usePathname: () => path }));

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
};

const stats = (pendingPayouts: number, pendingCampaigns: number): AdminStats => ({
  totalUsers: 0,
  totalCampaigns: 0,
  activeCampaigns: 0,
  pendingCampaigns,
  pendingPayouts,
  commissionRate: 0.3,
});

describe("Admin console layout", () => {
  beforeEach(() => {
    path = "/";
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

  it("marks the current route and shows it in the breadcrumb", () => {
    path = "/users";
    render(<AdminLayout>x</AdminLayout>);
    const link = screen.getByRole("link", { name: "Хэрэглэгчид" });
    expect(link.getAttribute("aria-current")).toBe("page");
    expect(
      screen.getByRole("navigation", { name: "Breadcrumb" }).textContent,
    ).toContain("Хэрэглэгчид");
  });

  it("adds a detail crumb on nested routes", () => {
    path = "/campaigns/4";
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
    expect(
      screen.getByRole("link", { name: /Кампани модераци\s*5/ }),
    ).toBeTruthy();
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
