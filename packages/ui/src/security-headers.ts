/**
 * HTTP security headers shared by every Next.js app in the workspace, so the
 * panels and the landing page cannot drift apart. Pure functions: each app's
 * next.config.ts calls `securityHeaderRoutes(...)` from `headers()`.
 *
 * Why these headers:
 * - The admin panel approves payouts and campaigns with one click, so no page
 *   may be framed by another site (clickjacking): `frame-ancestors 'none'`
 *   plus `X-Frame-Options` for browsers that ignore CSP.
 * - The JWT lives in localStorage, so an injected script could read it; the
 *   CSP limits where any script may send data (`connect-src`) to this site and
 *   the backend API.
 */

/** Where the panels' lib/api.ts sends requests when NEXT_PUBLIC_API_BASE_URL is unset. */
export const DEFAULT_API_BASE_URL = "http://localhost:8080";

/** Path pattern that matches every route, `/` included (zero or more segments). */
export const ALL_ROUTES = "/:path*";

/** The panels send no referrer at all: their URLs name campaigns, payouts and users. */
export const PANEL_REFERRER_POLICY = "no-referrer";

/** The public landing page lets the store / panel it links to see where visitors came from. */
export const LANDING_REFERRER_POLICY = "strict-origin-when-cross-origin";

export type ReferrerPolicy =
  | typeof PANEL_REFERRER_POLICY
  | typeof LANDING_REFERRER_POLICY;

/** None of the apps uses the camera, microphone or location. */
const PERMISSIONS_POLICY = "camera=(), microphone=(), geolocation=()";

/** One year, the minimum the HSTS preload list accepts. */
const HSTS_MAX_AGE_SECONDS = 31_536_000;

export type SecurityHeader = { key: string; value: string };

export type SecurityHeaderOptions = {
  /**
   * Origin of the backend API the browser calls (fetch + campaign cover
   * images). Omit it for an app that talks to no API (the landing page).
   */
  apiOrigin?: string;
  /** True under `next dev`: React/HMR need eval and a websocket. */
  dev: boolean;
  /** Defaults to {@link PANEL_REFERRER_POLICY}. */
  referrerPolicy?: ReferrerPolicy;
};

/**
 * The origin (scheme + host + port) of an API base URL such as
 * NEXT_PUBLIC_API_BASE_URL; falls back to {@link DEFAULT_API_BASE_URL} exactly
 * like the panels' lib/api.ts. Throws on a malformed URL so a bad deploy
 * setting fails the build instead of shipping a broken CSP.
 */
export function apiOriginOf(baseUrl: string | undefined): string {
  return new URL(baseUrl || DEFAULT_API_BASE_URL).origin;
}

/**
 * The Content-Security-Policy value. Without nonces (the apps are static or
 * client-rendered), so Next's inline bootstrap scripts need 'unsafe-inline';
 * see Next's "Content Security Policy → Without Nonces" guide.
 */
export function contentSecurityPolicy({
  apiOrigin,
  dev,
}: Pick<SecurityHeaderOptions, "apiOrigin" | "dev">): string {
  const api = apiOrigin ? [apiOrigin] : [];
  // React uses eval only in development (server error stacks); never in production.
  const devScripts = dev ? ["'unsafe-eval'"] : [];
  // The dev server's hot reload talks over a websocket.
  const devConnect = dev ? ["ws:"] : [];
  const directives: [string, string[]][] = [
    ["default-src", ["'self'"]],
    ["script-src", ["'self'", "'unsafe-inline'", ...devScripts]],
    ["style-src", ["'self'", "'unsafe-inline'"]],
    // data:/blob: for next/image placeholders and the local cover preview;
    // the API serves campaign cover images.
    ["img-src", ["'self'", "data:", "blob:", ...api]],
    // next/font self-hosts every font under /_next/static.
    ["font-src", ["'self'", "data:"]],
    ["connect-src", ["'self'", ...api, ...devConnect]],
    ["frame-ancestors", ["'none'"]],
    ["object-src", ["'none'"]],
    ["base-uri", ["'self'"]],
    ["form-action", ["'self'"]],
  ];
  return directives
    .map(([name, sources]) => `${name} ${sources.join(" ")}`)
    .join("; ");
}

/** Every security header, in the `{ key, value }` shape Next's `headers()` expects. */
export function securityHeaders(options: SecurityHeaderOptions): SecurityHeader[] {
  const headers: SecurityHeader[] = [
    { key: "Content-Security-Policy", value: contentSecurityPolicy(options) },
    { key: "X-Frame-Options", value: "DENY" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    {
      key: "Referrer-Policy",
      value: options.referrerPolicy ?? PANEL_REFERRER_POLICY,
    },
    { key: "Permissions-Policy", value: PERMISSIONS_POLICY },
  ];
  // Production sits behind HTTPS; browsers ignore HSTS over plain http, so the
  // Docker stack on http://localhost is unaffected. Dev servers never use TLS.
  if (!options.dev) {
    headers.push({
      key: "Strict-Transport-Security",
      value: `max-age=${HSTS_MAX_AGE_SECONDS}; includeSubDomains`,
    });
  }
  return headers;
}

/** The whole `headers()` result: the security headers on every route. */
export function securityHeaderRoutes(options: SecurityHeaderOptions) {
  return [{ source: ALL_ROUTES, headers: securityHeaders(options) }];
}
