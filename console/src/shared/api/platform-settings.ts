import type { Schema } from "@uziy/api-types";
import { apiFetch } from "./http";

export type PlatformSettings = Schema<"PlatformSettingsDto">;

/** Public read; the admin area writes it with `adminApi.updateSettings`. */
export const platformSettingsApi = {
  get: () => apiFetch<PlatformSettings>("/platform-settings", { anonymous: true }),
};
