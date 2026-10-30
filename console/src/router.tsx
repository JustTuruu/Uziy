import {
  createBrowserHistory,
  createRootRoute,
  createRoute,
  createRouter,
  lazyRouteComponent,
  Outlet,
  redirect,
  type AnyRoute,
  type RouterHistory,
} from "@tanstack/react-router";
import AdminLayout from "@admin/admin-layout";
import CompanyLayout from "@company/company-layout";
import { auth } from "@shared/api/http";
import { Link } from "@shared/navigation";
import { areaRedirect, type ConsoleRole } from "@shared/session";
import LoginPage from "./login/login-page";

// One app, two areas (owner, 2026-10-30): the company console at the root, the super-admin console under /admin.
// Each area's pages load on first visit, so a company never downloads the admin pages.

/** Pattern: Guard — runs before an area's pages render; see `areaRedirect`. */
function guard(area: ConsoleRole) {
  return () => {
    const to = areaRedirect(area, auth.getToken(), auth.getUser());
    if (to) throw redirect({ to, replace: true });
  };
}

function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 text-[var(--color-text-secondary)]">
      <p className="text-sm">Хуудас олдсонгүй.</p>
      <Link href="/" className="text-sm font-medium text-[var(--color-primary)] hover:underline">
        Нүүр хуудас руу буцах
      </Link>
    </div>
  );
}

const root = createRootRoute({ component: Outlet, notFoundComponent: NotFound });

const login = createRoute({ getParentRoute: () => root, path: "/login", component: LoginPage });

const company = createRoute({
  getParentRoute: () => root,
  id: "company",
  beforeLoad: guard("COMPANY"),
  component: () => (
    <CompanyLayout>
      <Outlet />
    </CompanyLayout>
  ),
});

const admin = createRoute({
  getParentRoute: () => root,
  path: "/admin",
  beforeLoad: guard("ADMIN"),
  component: () => (
    <AdminLayout>
      <Outlet />
    </AdminLayout>
  ),
});

type PageModule = () => Promise<{ default: () => React.ReactNode }>;

function pages(parent: AnyRoute, table: [path: string, load: PageModule][]) {
  return table.map(([path, load]) =>
    createRoute({ getParentRoute: () => parent, path, component: lazyRouteComponent(load) }),
  );
}

const companyPages = pages(company, [
  ["/", () => import("@company/pages/dashboard-page")],
  ["/campaigns", () => import("@company/pages/campaigns-page")],
  ["/campaigns/new", () => import("@company/pages/new-campaign-page")],
  ["/campaigns/$id", () => import("@company/pages/campaign-detail-page")],
  ["/analytics", () => import("@company/pages/analytics-page")],
  ["/billing", () => import("@company/pages/billing-page")],
  ["/settings", () => import("@company/pages/settings-page")],
]);

const adminPages = pages(admin, [
  ["/", () => import("@admin/pages/dashboard-page")],
  ["payouts", () => import("@admin/pages/payouts-page")],
  ["campaigns", () => import("@admin/pages/campaigns-page")],
  ["campaigns/$id", () => import("@admin/pages/campaign-detail-page")],
  ["users", () => import("@admin/pages/users-page")],
  ["companies", () => import("@admin/pages/companies-page")],
  ["companies/$id", () => import("@admin/pages/company-detail-page")],
  ["insights", () => import("@admin/pages/insights-page")],
  ["finance", () => import("@admin/pages/finance-page")],
  ["pricing", () => import("@admin/pages/pricing-page")],
  ["admins", () => import("@admin/pages/admins-page")],
]);

export const routeTree = root.addChildren([
  login,
  company.addChildren(companyPages),
  admin.addChildren(adminPages),
]);

/** The app's router; tests pass a memory history. */
export function createAppRouter(history: RouterHistory = createBrowserHistory()) {
  return createRouter({ routeTree, history, defaultPreload: "intent" });
}
