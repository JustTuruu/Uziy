import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth, type Me } from "@/lib/api";
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

describe("Admin console layout", () => {
  beforeEach(() => {
    path = "/";
    window.localStorage.clear();
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
});
