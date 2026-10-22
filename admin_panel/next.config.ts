import type { NextConfig } from "next";
import { apiOriginOf, securityHeaderRoutes } from "@uziy/ui/security-headers";

const nextConfig: NextConfig = {
  // Shared design system ships as TypeScript source.
  transpilePackages: ["@uziy/ui"],
  // Whitelist non-localhost origins for the dev server so HMR, fonts, and
  // other /_next/* resources load when hitting the machine over the LAN
  // (e.g. from a phone). Only applies to `next dev`, not production.
  allowedDevOrigins: ["192.168.1.8", "localhost", "127.0.0.1"],
  // No framing (payout/campaign decisions are one click) and a CSP that only
  // lets scripts talk to this site and the API. The API origin is read from
  // the same variable lib/api.ts uses, at build time like the client bundle.
  async headers() {
    return securityHeaderRoutes({
      apiOrigin: apiOriginOf(process.env.NEXT_PUBLIC_API_BASE_URL),
      dev: process.env.NODE_ENV === "development",
    });
  },
};

export default nextConfig;
