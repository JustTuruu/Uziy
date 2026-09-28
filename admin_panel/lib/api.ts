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

export interface Campaign {
  id: number;
  title: string;
  videoUrl: string;
  durationSeconds: number;
  targetGender: "ALL" | Gender;
  minAge: number;
  maxAge: number;
  targetCity: string;
  totalBudget: number;
  remainingBudget: number;
  costPerView: number;
  rewardPerUser: number;
  status: "PENDING" | "ACTIVE" | "PAUSED" | "COMPLETED" | "REJECTED";
  createdAt: string;
}

export const companyApi = {
  list: () => apiFetch<Campaign[]>("/company/campaigns"),
  get: (id: number) => apiFetch<Campaign>(`/company/campaigns/${id}`),
  create: (body: Omit<Campaign, "id" | "status" | "createdAt" | "remainingBudget"> & {
    questions: {
      prompt: string;
      type: "SINGLE_CHOICE" | "MULTI_CHOICE" | "TEXT";
      options: string[];
      required: boolean;
    }[];
  }) => apiFetch<Campaign>("/company/campaigns", { method: "POST", body }),
  setStatus: (id: number, status: Campaign["status"]) =>
    apiFetch<Campaign>(`/company/campaigns/${id}/status?status=${status}`, {
      method: "PATCH",
    }),
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

export const adminApi = {
  stats: () => apiFetch<AdminStats>("/admin/stats"),
  users: () => apiFetch<AdminUser[]>("/admin/users"),
  verify: (id: number) =>
    apiFetch<AdminUser>(`/admin/users/${id}/verify`, { method: "PATCH" }),
  campaigns: (status?: Campaign["status"]) =>
    apiFetch<Campaign[]>(
      status ? `/admin/campaigns?status=${status}` : "/admin/campaigns",
    ),
  moderate: (id: number, decision: "ACTIVE" | "REJECTED") =>
    apiFetch<Campaign>(
      `/admin/campaigns/${id}/moderate?decision=${decision}`,
      { method: "PATCH" },
    ),
  pendingPayouts: () => apiFetch<Payout[]>("/admin/payouts"),
  decidePayout: (id: number, decision: "APPROVED" | "REJECTED", reason?: string) =>
    apiFetch<Payout>(
      `/admin/payouts/${id}/decision?decision=${decision}${
        reason ? `&reason=${encodeURIComponent(reason)}` : ""
      }`,
      { method: "PATCH" },
    ),
};
