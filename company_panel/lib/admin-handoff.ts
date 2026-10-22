// One sign-in page for companies and admins (owner, 2026-10-22). An admin who signs in here is sent on to the
// admin panel — a different origin with its own storage — without this site ever storing the admin's token: the
// token only buys a one-time, 60-second code, and the code travels in the URL fragment, which browsers never send
// to a server and the admin panel removes from the address bar at once.

import { handoffApi } from "./api";

/** Where the admin panel lives; set per deployment. */
export const ADMIN_PANEL_URL = (process.env.NEXT_PUBLIC_ADMIN_PANEL_URL ?? "http://localhost:3001").replace(
  /\/+$/,
  "",
);

export const ADMIN_HANDOFF_PATH = "/login/handoff";

/** The admin panel page that spends {@code code}; the code is in the fragment, never in the query. */
export function adminHandoffUrl(code: string, base: string = ADMIN_PANEL_URL): string {
  return `${base}${ADMIN_HANDOFF_PATH}#code=${encodeURIComponent(code)}`;
}

/**
 * Trades the admin's token for a code and leaves for the admin panel. {@code go} is injectable for tests.
 * A failure rejects, so the login form shows it.
 */
export async function handOffToAdmin(
  adminToken: string,
  go: (url: string) => void = (url) => window.location.assign(url),
): Promise<void> {
  const { code } = await handoffApi.create(adminToken);
  go(adminHandoffUrl(code));
}
