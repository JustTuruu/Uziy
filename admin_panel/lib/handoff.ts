// Admins sign in on the company login page (owner, 2026-10-22); this panel has no sign-in form of its own. It sends
// signed-out visitors there and spends the one-time code that page hands over in the URL fragment.

/** The one sign-in page; set per deployment. */
export const COMPANY_PANEL_URL = (process.env.NEXT_PUBLIC_COMPANY_PANEL_URL ?? "http://localhost:3000").replace(
  /\/+$/,
  "",
);
export const SIGN_IN_URL = `${COMPANY_PANEL_URL}/login`;

/** Said when the code is missing, spent or too old (same words as the backend). */
export const HANDOFF_EXPIRED = "Нэвтрэх холбоосны хугацаа дууссан байна. Дахин нэвтэрнэ үү";

/** The code from a `#code=…` fragment, or null. */
export function codeFromHash(hash: string): string | null {
  const code = new URLSearchParams(hash.replace(/^#/, "")).get("code");
  return code && code.trim() ? code : null;
}

/** Leaves for another site without leaving this page in the history. Its own function so tests can replace it. */
export function leaveFor(url: string): void {
  window.location.replace(url);
}
