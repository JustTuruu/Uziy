// The admin area's calls to the backend. The plumbing every area shares (token, fetch, errors, sign-in) lives in
// @shared/api; it is re-exported here so the admin pages import one module. Pattern: Facade.
// Response shapes come from the generated @uziy/api-types — never retype a DTO by hand.

import type { Schema } from "@uziy/api-types";
import { apiFetch } from "@shared/api/http";
import type { PlatformSettings } from "@shared/api/platform-settings";

export {
  ApiError,
  GENERIC_ERROR_MESSAGE,
  NETWORK_ERROR_MESSAGE,
  apiFetch,
  auth,
  mediaUrl,
  useStoredUser,
} from "@shared/api/http";
export { platformSettingsApi, type PlatformSettings } from "@shared/api/platform-settings";
export type { AuthResponse, Me } from "@shared/api/types";

export type Campaign = Schema<"CampaignDto">;
export type CampaignStatus = Campaign["status"];
export type AdminStats = Schema<"AdminStats">;
export type AdminUser = Schema<"UserDto">;
export type Payout = Schema<"PayoutDto">;
export type AdminCampaignDetail = Schema<"CampaignDetailDto">;

export const adminApi = {
  stats: () => apiFetch<AdminStats>("/admin/stats"),
  users: () => apiFetch<AdminUser[]>("/admin/users"),
  user: (id: number) => apiFetch<AdminUser>(`/admin/users/${id}`),
  verify: (id: number) =>
    apiFetch<AdminUser>(`/admin/users/${id}/verify`, { method: "PATCH" }),
  /** The account's remembered browsers must pass the SMS step again (204). */
  forgetTrustedDevices: (id: number) =>
    apiFetch<null>(`/admin/users/${id}/trusted-devices/forget`, {
      method: "POST",
    }),
  campaigns: (opts?: { status?: CampaignStatus; companyId?: number }) => {
    const params = new URLSearchParams();
    if (opts?.status) params.set("status", opts.status);
    if (opts?.companyId !== undefined)
      params.set("companyId", String(opts.companyId));
    const qs = params.toString();
    return apiFetch<Campaign[]>(
      qs ? `/admin/campaigns?${qs}` : "/admin/campaigns",
    );
  },
  campaign: (id: number) =>
    apiFetch<AdminCampaignDetail>(`/admin/campaigns/${id}`),
  uploadImage: (id: number, file: File) => {
    const body = new FormData();
    body.append("file", file);
    return apiFetch<{ thumbnailUrl: string }>(`/admin/campaigns/${id}/image`, {
      method: "POST",
      body,
    });
  },
  removeImage: (id: number) =>
    apiFetch<{ thumbnailUrl: null }>(`/admin/campaigns/${id}/image`, {
      method: "DELETE",
    }),
  /** Approving may set the campaign's own commission; what the company paid is re-split at it. */
  moderate: (id: number, decision: "ACTIVE" | "REJECTED", commissionPercent?: number) =>
    apiFetch<Campaign>(
      `/admin/campaigns/${id}/moderate?decision=${decision}${
        commissionPercent === undefined ? "" : `&commissionPercent=${commissionPercent}`
      }`,
      { method: "PATCH" },
    ),
  pendingPayouts: () => apiFetch<Payout[]>("/admin/payouts"),
  payoutHistory: () => apiFetch<Payout[]>("/admin/payouts/history"),
  decidePayout: (
    id: number,
    decision: "APPROVED" | "REJECTED",
    reason?: string,
  ) =>
    apiFetch<Payout>(
      `/admin/payouts/${id}/decision?decision=${decision}${
        reason ? `&reason=${encodeURIComponent(reason)}` : ""
      }`,
      { method: "PATCH" },
    ),
  /** `commissionPercent` is the video campaigns' default, `surveyCommissionPercent` the survey-only one. */
  updateSettings: (body: {
    commissionPercent: number;
    surveyCommissionPercent: number;
    minRewardPerViewer: number;
  }) =>
    apiFetch<PlatformSettings>("/admin/platform-settings", {
      method: "PATCH",
      body,
    }),
};

// --- Company accounts (made by the admin; companies cannot register) -------

export type CompanyAccount = Schema<"CompanyAccountDto">;

export interface NewCompanyBody {
  companyName: string;
  phoneNumber: string;
  /** Temporary password the admin hands over; never shown again after creation. */
  password: string;
}

export const companiesApi = {
  list: () => apiFetch<CompanyAccount[]>("/admin/companies"),
  create: (body: NewCompanyBody) =>
    apiFetch<CompanyAccount>("/admin/companies", { method: "POST", body }),
};

// --- Admin accounts (made by another admin; admins are never self-created) --

export type AdminAccount = Schema<"AdminAccountDto">;

export interface NewAdminBody {
  phoneNumber: string;
  /** Temporary password handed over; the new admin still proves the phone by SMS at every login. */
  password: string;
}

export const adminsApi = {
  list: () => apiFetch<AdminAccount[]>("/admin/admins"),
  create: (body: NewAdminBody) =>
    apiFetch<AdminAccount>("/admin/admins", { method: "POST", body }),
};

// --- Anonymous statistics (super admin only) --------------------------------

/** A group's size, or null when it is under the minimum and must not be shown. */
export type InsightGroup = Schema<"Group">;
export type InsightsOverview = Schema<"Overview">;
export type InsightQuestion = Schema<"QuestionSummary">;

export interface InsightFilter {
  gender?: "MALE" | "FEMALE" | null;
  ageBand?: string | null;
  city?: string | null;
}

export type OptionShare = Schema<"OptionShare">;
export type InsightDistribution = Schema<"Distribution">;
export type InsightSegmentRow = Schema<"SegmentRow">;
export type InsightSegments = Schema<"Segments">;
export type AccessLogEntry = Schema<"AccessLogEntry">;

/** `?gender=…&ageBand=…&city=…` for the filters that are set; "" when none. */
export function insightFilterQuery(filter: InsightFilter): string {
  const params = new URLSearchParams();
  if (filter.gender) params.set("gender", filter.gender);
  if (filter.ageBand) params.set("ageBand", filter.ageBand);
  if (filter.city) params.set("city", filter.city);
  const q = params.toString();
  return q ? `?${q}` : "";
}

/** Every call is recorded server-side in the data access log. */
export const insightsApi = {
  overview: () => apiFetch<InsightsOverview>("/admin/insights/overview"),
  questions: () => apiFetch<InsightQuestion[]>("/admin/insights/questions"),
  distribution: (id: number, filter: InsightFilter) =>
    apiFetch<InsightDistribution>(
      `/admin/insights/questions/${id}${insightFilterQuery(filter)}`,
    ),
  segments: (id: number) =>
    apiFetch<InsightSegments>(`/admin/insights/questions/${id}/segments`),
  exportCsv: (id: number) =>
    apiFetch<string>(`/admin/insights/questions/${id}/export.csv`, {
      responseType: "text",
    }),
  accessLog: () => apiFetch<AccessLogEntry[]>("/admin/insights/access-log"),
};
