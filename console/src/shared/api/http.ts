// Thin fetch client for the Spring Boot backend, used by the company and the admin area alike.
// - Reads VITE_API_BASE_URL at build time; falls back to localhost:8080 for dev.
// - Stores the JWT in localStorage and forwards it on every call.
// - Throws ApiError on non-2xx responses with the status code + parsed body.

import { useMemo, useSyncExternalStore } from "react";
import { DEFAULT_API_BASE_URL } from "@uziy/ui/security-headers";
import type { Me } from "./types";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || DEFAULT_API_BASE_URL;

const TOKEN_KEY = "uziy.jwt";
const USER_KEY = "uziy.user";

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

/** Token / current-user storage (localStorage-backed). */
export const auth = {
  getToken(): string | null {
    return window.localStorage.getItem(TOKEN_KEY);
  },

  setToken(token: string): void {
    window.localStorage.setItem(TOKEN_KEY, token);
  },

  /** Signs out. The browser's device token (`@uziy/ui` deviceTokenStore) stays: it is what skips the SMS next time. */
  clear(): void {
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(USER_KEY);
  },

  setUser(me: Me): void {
    window.localStorage.setItem(USER_KEY, JSON.stringify(me));
  },

  getUser(): Me | null {
    return parseUser(window.localStorage.getItem(USER_KEY));
  },
};

function parseUser(raw: string | null): Me | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Me;
  } catch {
    return null;
  }
}

function subscribeToStorage(onChange: () => void): () => void {
  window.addEventListener("storage", onChange);
  return () => window.removeEventListener("storage", onChange);
}

/**
 * The signed-in user from localStorage, or null. Read it with this hook instead of `auth.getUser()` + an effect,
 * so a sign-out in another tab shows here too.
 */
export function useStoredUser(): Me | null {
  const raw = useSyncExternalStore(
    subscribeToStorage,
    () => window.localStorage.getItem(USER_KEY),
    () => null,
  );
  return useMemo(() => parseUser(raw), [raw]);
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  /** Skip Authorization header even if a token exists (e.g. /auth/login). */
  anonymous?: boolean;
  /** "text": return the body as a string (e.g. a CSV download) instead of parsed JSON. */
  responseType?: "json" | "text";
}

export async function apiFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const url = `${API_BASE_URL}${path}`;
  const headers: Record<string, string> = {};

  // A file upload: the browser writes the multipart boundary itself.
  const multipart = opts.body instanceof FormData;
  if (opts.body !== undefined && !multipart) headers["Content-Type"] = "application/json";

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

/** A media path from the API (e.g. a cover) as an absolute URL; full URLs pass through. */
export function mediaUrl(path: string): string {
  return new URL(path, API_BASE_URL).toString();
}
