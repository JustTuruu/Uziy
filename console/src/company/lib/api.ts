// The company area's calls to the backend. The plumbing every area shares (token, fetch, errors, sign-in) lives in
// @shared/api; it is re-exported here so the company pages import one module. Pattern: Facade.
// Response shapes come from the generated @uziy/api-types — never retype a DTO by hand.

import type { Schema } from "@uziy/api-types";
import { apiFetch } from "@shared/api/http";

export {
  ApiError,
  GENERIC_ERROR_MESSAGE,
  NETWORK_ERROR_MESSAGE,
  apiFetch,
  auth,
  mediaUrl,
  useStoredUser,
} from "@shared/api/http";
export { authApi, type LoginResult } from "@shared/api/auth-api";
export { platformSettingsApi, type PlatformSettings } from "@shared/api/platform-settings";
export type { AuthResponse, Me } from "@shared/api/types";

export type Campaign = Schema<"CampaignDto">;
export type CampaignStatus = Campaign["status"];
type Gender = NonNullable<Schema<"Me">["gender"]>;


/**
 * The backend keeps the question type as a plain string, so the generated types cannot list it.
 * RATING is the 5-point Маш муу … Маш сайн mood slider (older questions: 3 points); its options are fixed by the
 * backend. QUIZ asks about the video and has one correct option (`correctAnswer`) the viewer must pick.
 */
export type QuestionType = "SINGLE_CHOICE" | "MULTI_CHOICE" | "TEXT" | "RATING" | "QUIZ";

interface NewCampaignQuestion {
  prompt: string;
  type: QuestionType;
  options: string[];
  required: boolean;
  /** Only for QUIZ: the option the viewer must pick. Never sent to the viewer app. */
  correctAnswer?: string;
}

/**
 * POST /company/campaigns body. The server prices the campaign itself from
 * the current platform settings, so the client sends the budget plus
 * EXACTLY ONE of targetViewers / rewardPerUser (never a cost per view).
 */
export type CreateCampaignBody = {
  title: string;
  hasVideo: boolean;
  videoUrl: string;
  durationSeconds: number;
  targetGender: "ALL" | Gender;
  minAge: number;
  maxAge: number;
  targetCity: string;
  /** Whole ₮ the company is willing to spend; it is charged at most this. */
  totalBudget: number;
  questions: NewCampaignQuestion[];
} & (
  | { targetViewers: number; rewardPerUser?: never }
  | { rewardPerUser: number; targetViewers?: never }
);

export type Payment = Schema<"PaymentDto">;
export type PaymentStatus = Payment["status"];
export type PayCampaignResponse = Schema<"PayCampaignResponse">;

export const companyApi = {
  list: () => apiFetch<Campaign[]>("/company/campaigns"),
  get: (id: number) => apiFetch<Campaign>(`/company/campaigns/${id}`),
  /** Creates the campaign in AWAITING_PAYMENT; pay it with `pay(id)`. */
  create: (body: CreateCampaignBody) =>
    apiFetch<Campaign>("/company/campaigns", { method: "POST", body }),
  /** ACTIVE→PAUSED, PAUSED→ACTIVE, ACTIVE|PAUSED→COMPLETED only (else 409). */
  setStatus: (id: number, status: "ACTIVE" | "PAUSED" | "COMPLETED") =>
    apiFetch<Campaign>(`/company/campaigns/${id}/status?status=${status}`, {
      method: "PATCH",
    }),
  /**
   * Pays for an AWAITING_PAYMENT campaign (simulated for now; QPay later).
   * On success the campaign moves to PENDING for admin moderation.
   */
  pay: (id: number) =>
    apiFetch<PayCampaignResponse>(`/company/campaigns/${id}/pay`, {
      method: "POST",
    }),
  /** The caller's campaign payments, newest first. */
  payments: () => apiFetch<Payment[]>("/company/payments"),
  /** Sets the cover; only before approval (AWAITING_PAYMENT / PENDING), else 409. */
  uploadImage: (id: number, file: File) => {
    const body = new FormData();
    body.append("file", file);
    return apiFetch<{ thumbnailUrl: string }>(
      `/company/campaigns/${id}/image`,
      { method: "POST", body },
    );
  },
  removeImage: (id: number) =>
    apiFetch<{ thumbnailUrl: null }>(`/company/campaigns/${id}/image`, {
      method: "DELETE",
    }),
};

// --- Analytics (company) ----------------------------------------------------

/** A labelled count: a gender, an age band, a city or an answer option. */
export type AnalyticsSlice = Schema<"Slice">;
export type AnalyticsTotals = Schema<"Totals">;
export type CampaignPerformance = Schema<"CampaignPerformance">;
export type DailyResponses = Schema<"DailyViews">;
/** Who completed the selected campaign(s). Null while there are too few responses to stay anonymous. */
export type AnalyticsAudience = Schema<"Audience">;
export type QuestionBreakdown = Schema<"QuestionBreakdown">;
/** One choice question answered by segment; every option's counts line up with `segments`. */
export type SegmentBreakdown = Schema<"SegmentBreakdown">;
export type AnalyticsReport = Schema<"AnalyticsResponse">;

export const analyticsApi = {
  get: (opts: { days: number; campaignId?: number }) => {
    const query = new URLSearchParams({ days: String(opts.days) });
    if (opts.campaignId !== undefined) {
      query.set("campaignId", String(opts.campaignId));
    }
    return apiFetch<AnalyticsReport>(`/company/analytics?${query}`);
  },
};
