// Thin fetch client for the Spring Boot backend.
// - Reads NEXT_PUBLIC_API_BASE_URL at build time; falls back to localhost:8080 for dev.
// - Stores the JWT in localStorage (client-side only) and forwards it on every call.
// - Throws ApiError on non-2xx responses with the status code + parsed body.

import { useMemo, useSyncExternalStore } from "react";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080";

const TOKEN_KEY = "uziy.jwt";
const USER_KEY = "uziy.user";

type Role = "VIEWER" | "COMPANY" | "ADMIN";
type Gender = "MALE" | "FEMALE";

export interface Me {
  id: number;
  phoneNumber: string;
  role: Role;
  gender: Gender | null;
  age: number | null;
  city: string | null;
  balance: number;
  isVerified: boolean;
  companyName: string | null;
}

export interface AuthResponse {
  token: string;
  user: Me;
}

/**
 * The backend words every error in Mongolian (`message`); these are only for when it could not be reached or
 * sent nothing to read — never the browser's English ("Failed to fetch") or the HTTP status text.
 */
export const NETWORK_ERROR_MESSAGE =
  "Сервертэй холбогдож чадсангүй. Интернэт холболтоо шалгаад дахин оролдоно уу";
export const GENERIC_ERROR_MESSAGE = "Алдаа гарлаа. Дахин оролдоно уу";

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public body: unknown,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/** Token / current-user storage (localStorage-backed, browser only). */
export const auth = {
  getToken(): string | null {
    if (typeof window === "undefined") return null;
    return window.localStorage.getItem(TOKEN_KEY);
  },

  setToken(token: string): void {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(TOKEN_KEY, token);
  },

  clear(): void {
    if (typeof window === "undefined") return;
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(USER_KEY);
  },

  setUser(me: Me): void {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(USER_KEY, JSON.stringify(me));
  },

  getUser(): Me | null {
    if (typeof window === "undefined") return null;
    const raw = window.localStorage.getItem(USER_KEY);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as Me;
    } catch {
      return null;
    }
  },
};

function subscribeToStorage(onChange: () => void): () => void {
  window.addEventListener("storage", onChange);
  return () => window.removeEventListener("storage", onChange);
}

/**
 * The signed-in user from localStorage, or null (also null during SSR and the
 * first hydration pass, so server and client markup match). Read it with this
 * hook instead of `auth.getUser()` + an effect.
 */
export function useStoredUser(): Me | null {
  const raw = useSyncExternalStore(
    subscribeToStorage,
    () => window.localStorage.getItem(USER_KEY),
    () => null,
  );
  return useMemo(() => {
    if (!raw) return null;
    try {
      return JSON.parse(raw) as Me;
    } catch {
      return null;
    }
  }, [raw]);
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  /** Skip Authorization header even if a token exists (e.g. /auth/login). */
  anonymous?: boolean;
  /** "text": return the body as a string (e.g. a CSV download) instead of parsed JSON. */
  responseType?: "json" | "text";
}

export async function apiFetch<T>(
  path: string,
  opts: RequestOptions = {},
): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const headers: Record<string, string> = {};

  const multipart = opts.body instanceof FormData;
  if (opts.body !== undefined && !multipart)
    headers["Content-Type"] = "application/json";

  if (!opts.anonymous) {
    const token = auth.getToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;
  }

  let res: Response;
  try {
    res = await fetch(url, {
      method: opts.method ?? "GET",
      headers,
      body: multipart
        ? (opts.body as FormData)
        : opts.body === undefined
          ? undefined
          : JSON.stringify(opts.body),
      credentials: "omit",
    });
  } catch {
    throw new ApiError(NETWORK_ERROR_MESSAGE, 0, null);
  }

  const text = await res.text();
  const parsed = text ? safeJson(text) : null;

  if (!res.ok) {
    throw new ApiError(messageOf(parsed), res.status, parsed);
  }

  return (opts.responseType === "text" ? text : parsed) as T;
}

/** The backend's own `message`, or the generic sentence when there is none. */
function messageOf(body: unknown): string {
  if (body && typeof body === "object" && "message" in body) {
    const message = (body as { message?: unknown }).message;
    if (typeof message === "string" && message.trim()) return message;
  }
  return GENERIC_ERROR_MESSAGE;
}

function safeJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

// --- High-level endpoints (thin wrappers so pages don't build URLs) --------

export interface LoginBody {
  phoneNumber: string;
  password: string;
}
export const authApi = {
  login: (body: LoginBody) =>
    apiFetch<AuthResponse>("/auth/login", {
      method: "POST",
      body,
      anonymous: true,
    }),
};

export type CampaignStatus =
  | "AWAITING_PAYMENT"
  | "PENDING"
  | "ACTIVE"
  | "PAUSED"
  | "COMPLETED"
  | "REJECTED";

export interface Campaign {
  thumbnailUrl?: string | null;
  id: number;
  title: string;
  videoUrl: string;
  durationSeconds: number;
  hasVideo: boolean;
  targetGender: "ALL" | Gender;
  minAge: number;
  maxAge: number;
  targetCity: string;
  /** What the company is charged (= cost per viewer × target viewers). */
  totalBudget: number;
  remainingBudget: number;
  /** What one viewer costs the company (reward + platform commission). */
  costPerView: number;
  rewardPerUser: number;
  /** How many viewers the campaign reaches; null only on very old rows. */
  targetViewers: number | null;
  /** Commission % snapshotted at creation; null for legacy campaigns. */
  commissionPercent: number | null;
  paidAt: string | null;
  status: CampaignStatus;
  createdAt: string;
}

export interface AdminStats {
  totalUsers: number;
  totalCampaigns: number;
  activeCampaigns: number;
  pendingCampaigns: number;
  pendingPayouts: number;
  commissionRate: number;
}

export interface AdminUser {
  id: number;
  phoneNumber: string;
  role: Role;
  gender: Gender | null;
  age: number | null;
  city: string | null;
  balance: number;
  isVerified: boolean;
  companyName: string | null;
  createdAt: string;
}

export interface Payout {
  id: number;
  userId: number;
  userPhone: string;
  amount: number;
  bank: string;
  accountNumber: string;
  accountName: string;
  status: "PENDING" | "APPROVED" | "REJECTED";
  isFirstPayout: boolean;
  requestedAt: string;
  decidedAt: string | null;
  rejectReason: string | null;
}

export interface AdminCampaignDetail {
  campaign: Campaign;
  companyId: number;
  companyName: string | null;
  completedViews: number;
  spentBudget: number;
}

export const adminApi = {
  stats: () => apiFetch<AdminStats>("/admin/stats"),
  users: () => apiFetch<AdminUser[]>("/admin/users"),
  user: (id: number) => apiFetch<AdminUser>(`/admin/users/${id}`),
  verify: (id: number) =>
    apiFetch<AdminUser>(`/admin/users/${id}/verify`, { method: "PATCH" }),
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
  moderate: (id: number, decision: "ACTIVE" | "REJECTED") =>
    apiFetch<Campaign>(`/admin/campaigns/${id}/moderate?decision=${decision}`, {
      method: "PATCH",
    }),
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
  updateSettings: (body: {
    commissionPercent: number;
    minRewardPerViewer: number;
  }) =>
    apiFetch<PlatformSettings>("/admin/platform-settings", {
      method: "PATCH",
      body,
    }),
};

// --- Platform settings (public read; admin write) --------------------------

export interface PlatformSettings {
  /** Platform's cut of every campaign budget, whole percent 1..90. */
  commissionPercent: number;
  /** Smallest reward a viewer may receive, whole ₮. */
  minRewardPerViewer: number;
  updatedAt: string;
}

export const platformSettingsApi = {
  get: () =>
    apiFetch<PlatformSettings>("/platform-settings", { anonymous: true }),
};

export function mediaUrl(path: string): string {
  return new URL(path, API_BASE_URL).toString();
}

// --- Anonymous statistics (super admin only) --------------------------------

/** A group's size, or null when it is under the minimum and must not be shown. */
export interface InsightGroup {
  label: string;
  people: number | null;
}

export interface InsightsOverview {
  minGroupSize: number;
  viewers: number;
  consentingViewers: number;
  consentPercent: number;
  byGender: InsightGroup[];
  byAgeBand: InsightGroup[];
  byCity: InsightGroup[];
  reportableQuestions: number;
}

export interface InsightQuestion {
  questionId: number;
  prompt: string;
  type: string;
  surveyTitle: string;
  companyName: string;
  /** Consenting respondents, rounded down to tens. */
  respondents: number;
  reportable: boolean;
}

export interface InsightFilter {
  gender?: "MALE" | "FEMALE" | null;
  ageBand?: string | null;
  city?: string | null;
}

export interface OptionShare {
  option: string;
  percent: number;
}

export interface InsightDistribution {
  questionId: number;
  prompt: string;
  type: string;
  filter: InsightFilter;
  suppressed: boolean;
  people: number | null;
  shares: OptionShare[];
}

export interface InsightSegmentRow {
  dimension: string;
  label: string;
  suppressed: boolean;
  people: number | null;
  shares: OptionShare[];
}

export interface InsightSegments {
  questionId: number;
  prompt: string;
  options: string[];
  rows: InsightSegmentRow[];
}

export interface AccessLogEntry {
  id: number;
  adminPhone: string;
  action: string;
  detail: string;
  at: string;
}

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
