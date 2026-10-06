import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { isActive, Sidebar, SidebarUser, Topbar, type NavItem } from "./sidebar";

let path = "/";
vi.mock("next/navigation", () => ({ usePathname: () => path }));
vi.mock("next/image", () => ({
  default: (p: { alt: string }) => <span role="img" aria-label={p.alt} />,
}));

const items: NavItem[] = [
  { href: "/", label: "Нүүр", icon: <i />, section: "Ерөнхий" },
  { href: "/users", label: "Хэрэглэгчид", icon: <i />, section: "Хяналт", badge: 3 },
  { href: "/pricing", label: "Шимтгэл", icon: <i /> },
];

describe("isActive", () => {
  it("matches exact and nested paths, root only exactly", () => {
    expect(isActive("/users", "/users")).toBe(true);
    expect(isActive("/users/4", "/users")).toBe(true);
    expect(isActive("/usersx", "/users")).toBe(false);
    expect(isActive("/users", "/")).toBe(false);
    expect(isActive("/", "/")).toBe(true);
  });
});

describe("<Sidebar>", () => {
  it("renders section headings once, badges, and the current page", () => {
    path = "/users/9";
    render(<Sidebar brand="Uziy" subtitle="Админ" items={items} />);
    expect(screen.getByText("Ерөнхий")).toBeInTheDocument();
    expect(screen.getByText("Хяналт")).toBeInTheDocument();
    expect(screen.getByText("3")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /Хэрэглэгчид/ })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByRole("link", { name: /Нүүр/ })).not.toHaveAttribute(
      "aria-current",
    );
  });
});

describe("<Topbar>", () => {
  it("shows the current item, plus a detail crumb on nested routes", () => {
    const { rerender } = render(<Topbar items={items} pathname="/users" />);
    const nav = () => screen.getByRole("navigation", { name: "Breadcrumb" });
    expect(nav().textContent).toContain("Хэрэглэгчид");
    expect(nav().textContent).not.toContain("Дэлгэрэнгүй");
    rerender(<Topbar items={items} pathname="/users/4" />);
    expect(nav().textContent).toContain("Дэлгэрэнгүй");
  });
});

describe("<SidebarUser>", () => {
  it("shows the user and calls onLogout when leaving", () => {
    const onLogout = vi.fn((e?: unknown) => e);
    render(<SidebarUser initials="SA" name="Админ" detail="+976 1" onLogout={onLogout} />);
    expect(screen.getByText("Админ")).toBeInTheDocument();
    const link = screen.getByRole("link", { name: "Гарах" });
    expect(link).toHaveAttribute("href", "/login");
    link.addEventListener("click", (e) => e.preventDefault());
    link.click();
    expect(onLogout).toHaveBeenCalledOnce();
  });
});
