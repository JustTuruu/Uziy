import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv, type Plugin } from "vite";
// A relative path, not "@uziy/ui/security-headers": Vite bundles the config's relative imports but hands package
// imports to Node, which cannot load the kit's TypeScript source.
import {
  apiOriginOf,
  nginxHeaderLines,
  securityHeaders,
  type SecurityHeaderOptions,
} from "../packages/ui/src/security-headers";

/** The console's port; the backend's CORS allows it. */
const PORT = 3000;

/** Where `vite build` writes the headers nginx sends with every response (docker/console.Dockerfile). */
const NGINX_HEADERS_FILE = path.resolve(__dirname, "build/nginx/security-headers.conf");

const headerRecord = (options: SecurityHeaderOptions) =>
  Object.fromEntries(securityHeaders(options).map(({ key, value }) => [key, value]));

/** After a production build, writes the same security headers for nginx. */
function nginxSecurityHeaders(options: SecurityHeaderOptions): Plugin {
  return {
    name: "uziy-nginx-security-headers",
    apply: "build",
    closeBundle() {
      mkdirSync(path.dirname(NGINX_HEADERS_FILE), { recursive: true });
      writeFileSync(NGINX_HEADERS_FILE, nginxHeaderLines(securityHeaders(options)));
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, __dirname, "VITE_");
  // No framing (payout/campaign decisions are one click) and a CSP that only lets scripts talk to this site and
  // the API. The production bundle has no inline script, so none is allowed there.
  const apiOrigin = apiOriginOf(env.VITE_API_BASE_URL);
  const live = { apiOrigin, inlineScripts: false };

  return {
    plugins: [react(), tailwindcss(), nginxSecurityHeaders({ ...live, dev: false })],
    resolve: {
      alias: {
        "@shared": path.resolve(__dirname, "src/shared"),
        "@company": path.resolve(__dirname, "src/company"),
        "@admin": path.resolve(__dirname, "src/admin"),
      },
    },
    server: { port: PORT, strictPort: true, headers: headerRecord({ ...live, dev: true }) },
    preview: { port: PORT, strictPort: true, headers: headerRecord({ ...live, dev: false }) },
    test: {
      environment: "happy-dom",
      globals: true,
      setupFiles: ["./vitest.setup.ts"],
      include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
      css: false,
    },
  };
});
