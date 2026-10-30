import type { Me, Role } from "./api/types";

/** The roles that may use the console; viewers have the app. */
export type ConsoleRole = Extract<Role, "COMPANY" | "ADMIN">;

export const LOGIN_PATH = "/login";
export const COMPANY_HOME = "/";
export const ADMIN_HOME = "/admin";

const HOMES: Record<ConsoleRole, string> = { COMPANY: COMPANY_HOME, ADMIN: ADMIN_HOME };

/** Where a signed-in account lands: companies at the root, admins under /admin. */
export function homeFor(role: Role): string {
  return role === "COMPANY" || role === "ADMIN" ? HOMES[role] : LOGIN_PATH;
}

/**
 * Pattern: Guard — where to send someone who opens an area of the console, or null to let them in. Without a
 * session they sign in; an account of the other area goes to its own home (a company never sees admin pages, and
 * the backend refuses the calls anyway).
 */
export function areaRedirect(area: ConsoleRole, token: string | null, user: Me | null): string | null {
  if (!token || !user) return LOGIN_PATH;
  return user.role === area ? null : homeFor(user.role);
}
