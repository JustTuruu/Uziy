import { describe, expect, it } from "vitest";
import {
  ALL_ROUTES,
  LANDING_REFERRER_POLICY,
  PANEL_REFERRER_POLICY,
  apiOriginOf,
  contentSecurityPolicy,
  securityHeaderRoutes,
  securityHeaders,
} from "./security-headers";

const API = "https://api.uziy.mn";

function headerMap(options: Parameters<typeof securityHeaders>[0]) {
  return Object.fromEntries(
    securityHeaders(options).map(({ key, value }) => [key, value]),
  );
}

function directive(csp: string, name: string): string[] {
  const found = csp
    .split("; ")
    .map((part) => part.split(" "))
    .find(([directiveName]) => directiveName === name);
  return found ? found.slice(1) : [];
}

describe("apiOriginOf", () => {
  it("keeps only scheme, host and port of the API base URL", () => {
    expect(apiOriginOf("https://api.uziy.mn/v1/")).toBe(API);
    expect(apiOriginOf("http://192.168.1.8:8080")).toBe("http://192.168.1.8:8080");
  });

  it("falls back to the panels' local API when the variable is unset or empty", () => {
    expect(apiOriginOf(undefined)).toBe("http://localhost:8080");
    expect(apiOriginOf("")).toBe("http://localhost:8080");
  });

  it("throws on a malformed URL so a bad deploy setting fails the build", () => {
    expect(() => apiOriginOf("not a url")).toThrow();
  });
});

describe("contentSecurityPolicy", () => {
  it("forbids framing, plugins and foreign base/form targets", () => {
    const csp = contentSecurityPolicy({ apiOrigin: API, dev: false });
    expect(directive(csp, "frame-ancestors")).toEqual(["'none'"]);
    expect(directive(csp, "object-src")).toEqual(["'none'"]);
    expect(directive(csp, "base-uri")).toEqual(["'self'"]);
    expect(directive(csp, "form-action")).toEqual(["'self'"]);
    expect(directive(csp, "default-src")).toEqual(["'self'"]);
  });

  it("lets the page call and load images from the API only, besides itself", () => {
    const csp = contentSecurityPolicy({ apiOrigin: API, dev: false });
    expect(directive(csp, "connect-src")).toEqual(["'self'", API]);
    expect(directive(csp, "img-src")).toEqual(["'self'", "data:", "blob:", API]);
    expect(directive(csp, "font-src")).toEqual(["'self'", "data:"]);
  });

  it("has no eval and no websocket in production", () => {
    const csp = contentSecurityPolicy({ apiOrigin: API, dev: false });
    expect(directive(csp, "script-src")).toEqual(["'self'", "'unsafe-inline'"]);
    expect(csp).not.toContain("'unsafe-eval'");
    expect(csp).not.toContain("ws:");
  });

  it("allows eval and the hot-reload websocket in development", () => {
    const csp = contentSecurityPolicy({ apiOrigin: API, dev: true });
    expect(directive(csp, "script-src")).toContain("'unsafe-eval'");
    expect(directive(csp, "connect-src")).toEqual(["'self'", API, "ws:"]);
  });

  it("names no other origin when the app talks to no API", () => {
    const csp = contentSecurityPolicy({ dev: false });
    expect(directive(csp, "connect-src")).toEqual(["'self'"]);
    expect(directive(csp, "img-src")).toEqual(["'self'", "data:", "blob:"]);
  });
});

describe("securityHeaders", () => {
  it("sends the anti-framing, sniffing and permission headers", () => {
    const headers = headerMap({ apiOrigin: API, dev: false });
    expect(headers["X-Frame-Options"]).toBe("DENY");
    expect(headers["X-Content-Type-Options"]).toBe("nosniff");
    expect(headers["Permissions-Policy"]).toBe(
      "camera=(), microphone=(), geolocation=()",
    );
    expect(headers["Content-Security-Policy"]).toBe(
      contentSecurityPolicy({ apiOrigin: API, dev: false }),
    );
  });

  it("sends no referrer by default and the landing policy when asked", () => {
    expect(headerMap({ dev: false })["Referrer-Policy"]).toBe(PANEL_REFERRER_POLICY);
    expect(
      headerMap({ dev: false, referrerPolicy: LANDING_REFERRER_POLICY })[
        "Referrer-Policy"
      ],
    ).toBe("strict-origin-when-cross-origin");
  });

  it("adds HSTS in production only", () => {
    expect(headerMap({ dev: false })["Strict-Transport-Security"]).toBe(
      "max-age=31536000; includeSubDomains",
    );
    expect(headerMap({ dev: true })).not.toHaveProperty("Strict-Transport-Security");
  });
});

describe("securityHeaderRoutes", () => {
  it("applies the headers to every route", () => {
    const routes = securityHeaderRoutes({ apiOrigin: API, dev: false });
    expect(routes).toEqual([
      { source: ALL_ROUTES, headers: securityHeaders({ apiOrigin: API, dev: false }) },
    ]);
    expect(ALL_ROUTES).toBe("/:path*");
  });
});
