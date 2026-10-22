// Thin fetch client for the Spring Boot backend.
// - Reads NEXT_PUBLIC_API_BASE_URL at build time; falls back to localhost:8080 for dev.
// - Stores the JWT in localStorage (client-side only) and forwards it on every call.
// - Throws ApiError on non-2xx responses with the status code + parsed body.

import { useMemo, useSyncExternalStore } from "react";
import type {
  ConsoleLoginBody,
  ConsoleLoginResult,
  PhoneCheck,
  VerifiedLogin,
} from "@uziy/ui";

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

  /** Signs out. The browser's device token (`@uziy/ui` deviceTokenStore) stays: it is what skips the SMS next time. */
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
}

export async function apiFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const headers: Record<string, string> = {};

  // A file upload: the browser writes the multipart boundary itself.
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

  return parsed as T;
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

/** `POST /auth/login`: a token (200), or on a browser the server does not recognise the SMS step (202). */
export type LoginResult = ConsoleLoginResult<Me>;

/** Also the `ConsoleLoginApi` the shared login flow (`@uziy/ui` useConsoleLogin) calls. */
export const authApi = {
  login: (body: ConsoleLoginBody) =>
    apiFetch<LoginResult>("/auth/login", {
      method: "POST",
      body,
      anonymous: true,
    }),
  phoneCheck: (verificationId: string) =>
    apiFetch<PhoneCheck>(
      `/auth/phone-verifications/${encodeURIComponent(verificationId)}`,
      { anonymous: true },
    ),
  /** Finishes the SMS step: the token, plus this browser's device token. */
  verify: (body: { phoneNumber: string; verificationId: string }) =>
    apiFetch<VerifiedLogin<Me>>("/auth/login/verify", {
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
  /** Cover image path on the API (see `mediaUrl`); null without one. */
  thumbnailUrl?: string | null;
}

/** RATING is the 5-point Маш муу … Маш сайн mood slider (older questions: 3 points); its options are fixed by the backend. */
export type QuestionType = "SINGLE_CHOICE" | "MULTI_CHOICE" | "TEXT" | "RATING";

interface NewCampaignQuestion {
  prompt: string;
  type: QuestionType;
  options: string[];
  required: boolean;
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

type PaymentProvider = "SIMULATED" | "QPAY" | "BANK_TRANSFER";
export type PaymentStatus = "PAID" | "FAILED" | "REFUNDED";

export interface Payment {
  id: number;
  campaignId: number;
  campaignTitle: string;
  amount: number;
  provider: PaymentProvider;
  status: PaymentStatus;
  /** Human-facing invoice number, e.g. "UZ-20260928-42". */
  reference: string;
  createdAt: string;
  paidAt: string | null;
}

export interface PayCampaignResponse {
  campaign: Campaign;
  payment: Payment;
}

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

/** A media path from the API (e.g. a cover) as an absolute URL; full URLs pass through. */
export function mediaUrl(path: string): string {
  return new URL(path, API_BASE_URL).toString();
}
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

// --- Analytics (company) ----------------------------------------------------

/** A labelled count: a gender, an age band, a city or an answer option. */
export interface AnalyticsSlice {
  label: string;
  count: number;
}

export interface AnalyticsTotals {
  campaignCount: number;
  activeCount: number;
  responses: number;
  rewardsPaid: number;
  spent: number;
  costPerResponse: number | null;
}

export interface CampaignPerformance {
  campaignId: number;
  title: string;
  status: CampaignStatus;
  hasVideo: boolean;
  targetViewers: number | null;
  responses: number;
  /** 0..100; null when the campaign has no viewer target. */
  reachPercent: number | null;
  spent: number;
  rewardsPaid: number;
  costPerResponse: number | null;
  /** Responses the remaining budget still pays for. */
  remainingResponses: number;
  responsesLast7Days: number;
  /** Days until the budget runs out at last week's pace; null when paused, finished or no recent responses. */
  daysLeft: number | null;
}

export interface DailyResponses {
  /** ISO date, e.g. "2026-10-07" (Ulaanbaatar calendar day). */
  date: string;
  responses: number;
}

/** Who completed the selected campaign(s). Null while there are too few responses to stay anonymous. */
export interface AnalyticsAudience {
  gender: AnalyticsSlice[];
  ageBands: AnalyticsSlice[];
  cities: AnalyticsSlice[];
}

export interface QuestionBreakdown {
  questionId: number;
  prompt: string;
  type: QuestionType;
  answered: number;
  /** Empty for free-text questions. */
  options: AnalyticsSlice[];
}

/** One choice question answered by segment; every option's counts line up with `segments`. */
export interface SegmentBreakdown {
  questionId: number;
  prompt: string;
  /** Segment label ("MALE", "FEMALE", "18–24", …) and how many of it answered. Only segments big enough to stay anonymous. */
  segments: AnalyticsSlice[];
  options: { label: string; counts: number[] }[];
}

export interface AnalyticsReport {
  days: number;
  totals: AnalyticsTotals;
  campaigns: CampaignPerformance[];
  daily: DailyResponses[];
  audience: AnalyticsAudience | null;
  /** Only filled when one campaign is selected; covers the campaign's whole life, whatever `days` is. */
  questions: QuestionBreakdown[];
  /** Only filled when one campaign is selected, and only for big-enough segments. */
  segments: SegmentBreakdown[];
}

export const analyticsApi = {
  get: (opts: { days: number; campaignId?: number }) => {
    const query = new URLSearchParams({ days: String(opts.days) });
    if (opts.campaignId !== undefined) {
      query.set("campaignId", String(opts.campaignId));
    }
    return apiFetch<AnalyticsReport>(`/company/analytics?${query}`);
  },
};
