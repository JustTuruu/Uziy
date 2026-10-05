import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Whitelist non-localhost origins for the dev server so HMR, fonts, and
  // other /_next/* resources load when hitting the machine over the LAN
  // (e.g. from a phone). Only applies to `next dev`, not production.
  allowedDevOrigins: ["192.168.1.8", "localhost", "127.0.0.1"],
};

export default nextConfig;
