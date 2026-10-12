import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Shared design system ships as TypeScript source.
  transpilePackages: ["@uziy/ui"],
};

export default nextConfig;
