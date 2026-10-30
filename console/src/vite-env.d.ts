/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Address the browser uses to reach the backend; baked in at build time. */
  readonly VITE_API_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
