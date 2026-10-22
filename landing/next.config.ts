import type { NextConfig } from "next";
import {
  LANDING_REFERRER_POLICY,
  securityHeaderRoutes,
} from "@uziy/ui/security-headers";

const nextConfig: NextConfig = {
  // Shared design system ships as TypeScript source.
  transpilePackages: ["@uziy/ui"],
  // The landing page calls no API, so its CSP names no other origin; its
  // links to the stores and the company panel are plain navigations.
  async headers() {
    return securityHeaderRoutes({
      dev: process.env.NODE_ENV === "development",
      referrerPolicy: LANDING_REFERRER_POLICY,
    });
  },
};

export default nextConfig;
