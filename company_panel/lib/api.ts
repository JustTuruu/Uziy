// Thin fetch client for the Spring Boot backend.
// - Reads NEXT_PUBLIC_API_BASE_URL at build time; falls back to localhost:8080 for dev.
// - Stores the JWT in localStorage (client-side only) and forwards it on every call.
// - Throws ApiError on non-2xx responses with the status code + parsed body.

export const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8080";

const TOKEN_KEY = "uziy.jwt";
const USER_KEY = "uziy.user";

export type Role = "VIEWER" | "COMPANY" | "ADMIN";
export type Gender = "MALE" | "FEMALE";

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

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  /** Skip Authorization header even if a token exists (e.g. /auth/login). */
  anonymous?: boolean;
}

export async function apiFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const headers: Record<string, string> = {};

  if (opts.body !== undefined) headers["Content-Type"] = "application/json";

  if (!opts.anonymous) {
    const token = auth.getToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(url, {
    method: opts.method ?? "GET",
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
    credentials: "omit",
  });

  const text = await res.text();
  const parsed = text ? safeJson(text) : null;

  if (!res.ok) {
    const message =
      (parsed && typeof parsed === "object" && "message" in parsed
        ? (parsed as { message?: string }).message
        : null) ?? res.statusText;
    throw new ApiError(message ?? `${res.status}`, res.status, parsed);
  }

  return parsed as T;
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

export interface NewCampaignQuestion {
  prompt: string;
  type: "SINGLE_CHOICE" | "MULTI_CHOICE" | "TEXT";
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

export type PaymentProvider = "SIMULATED" | "QPAY" | "BANK_TRANSFER";
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
};

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
  nationalId: string;
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
  moderate: (id: number, decision: "ACTIVE" | "REJECTED") =>
    apiFetch<Campaign>(
      `/admin/campaigns/${id}/moderate?decision=${decision}`,
      { method: "PATCH" },
    ),
  pendingPayouts: () => apiFetch<Payout[]>("/admin/payouts"),
  payoutHistory: () => apiFetch<Payout[]>("/admin/payouts/history"),
  decidePayout: (id: number, decision: "APPROVED" | "REJECTED", reason?: string) =>
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
