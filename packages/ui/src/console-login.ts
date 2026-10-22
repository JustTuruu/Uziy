"use client";

// The console login (company and admin panels), written once (owner, 2026-10-22: ask for the phone only on a
// browser the server does not recognise). The password is always asked. On an unknown browser the backend answers
// 202 with an SMS step: the person texts a code from the account's phone (verify.mn, short code 144773), the page
// polls the check and finishes with `POST /auth/login/verify`, which also hands out a device token. That token is
// kept in this browser (it survives logout — that is the point) and sent with the next logins, which are then
// signed in at once for DEVICE_TRUST_DAYS.

import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import type { SmsVerificationStatus } from "./sms-verification-card";

export type ConsoleRole = "ADMIN" | "COMPANY";

/** How long the backend remembers a browser after its SMS (`TrustedDeviceServiceImpl.TRUST_PERIOD`). */
export const DEVICE_TRUST_DAYS = 30;

/** How often the page asks whether the SMS has arrived (the viewer app polls at the same pace). */
export const CONSOLE_LOGIN_POLL_MS = 3000;

/** A check is treated as run out a little after its own deadline, in case the clocks differ slightly. */
export const EXPIRY_GRACE_MS = 10_000;

/** Where this browser keeps its device token (one per app origin). */
export const DEVICE_TOKEN_KEY = "uziy.device";

export const CONSOLE_LOGIN_COPY = {
  title: "Утсаа баталгаажуулах",
  subtitle: (maskedPhone: string) =>
    `Нэвтрэхийн тулд бүртгэлтэй утаснаасаа (${maskedPhone}) нэг SMS илгээнэ үү.`,
  deviceRemembered: `Энэ хөтөч ${DEVICE_TRUST_DAYS} хоног танигдана.`,
  back: "Буцах",
  wrongCredentials: "Утас эсвэл нууц үг буруу байна",
  checkForm: "Утасны дугаар болон нууц үгээ шалгана уу",
  newCodeReady: "Шинэ код үүслээ. Хуучин кодыг бүү илгээгээрэй.",
  submit: "Нэвтрэх",
  signingIn: "Нэвтэрч байна...",
} as const;

/** The SMS the account's phone must send, as `POST /auth/login` answers it (202). */
export interface ConsoleTwoStep {
  verificationId: string;
  /** Masked by the backend ("•••• 1122"). */
  phoneNumber: string;
  /** Whose login this is, so a panel can turn away the other console's account before any SMS. */
  role: string;
  shortcode: string;
  smsText: string;
  smsUri: string;
  /** The provider's own wording; show it unchanged. */
  displayInstruction: string;
  expiresAt: string;
}

export interface ConsoleLoginChallenge {
  twoStep: ConsoleTwoStep;
}

export interface SignedIn<U> {
  token: string;
  user: U;
}

/** `POST /auth/login/verify`: signed in, plus this browser's device token. */
export interface VerifiedLogin<U> extends SignedIn<U> {
  deviceToken: string;
  deviceTrustedUntil: string;
}

/** `POST /auth/login`: a token (200), or the SMS step (202). */
export type ConsoleLoginResult<U> = SignedIn<U> | ConsoleLoginChallenge;

export interface PhoneCheck {
  verificationId: string;
  status: SmsVerificationStatus;
  expiresAt: string;
}

export interface ConsoleLoginBody {
  phoneNumber: string;
  password: string;
  /** Left out when this browser has none. */
  deviceToken?: string;
}

/** The three calls the flow needs; each panel passes its own API client. */
export interface ConsoleLoginApi<U extends { role: string }> {
  login(body: ConsoleLoginBody): Promise<ConsoleLoginResult<U>>;
  phoneCheck(verificationId: string): Promise<PhoneCheck>;
  verify(body: { phoneNumber: string; verificationId: string }): Promise<VerifiedLogin<U>>;
}

export function isTwoStep<U>(res: ConsoleLoginResult<U>): res is ConsoleLoginChallenge {
  return "twoStep" in res && Boolean(res.twoStep);
}

/** True once `expiresAt` (ISO) plus the grace period is behind `now`. */
export function hasRunOut(expiresAt: string, now: number): boolean {
  const deadline = Date.parse(expiresAt);
  return Number.isFinite(deadline) && now > deadline + EXPIRY_GRACE_MS;
}

/** Only the 8 national digits, as typed or pasted. */
export function sanitizePhone(raw: string): string {
  return raw.replace(/\D/g, "").slice(0, 8);
}

/**
 * The device token of this browser. Storage can be missing or refuse access (private mode, blocked site data); the
 * login then simply asks for the SMS every time.
 */
export const deviceTokenStore = {
  get(): string | null {
    try {
      return window.localStorage.getItem(DEVICE_TOKEN_KEY);
    } catch {
      return null;
    }
  },
  set(token: string): void {
    try {
      window.localStorage.setItem(DEVICE_TOKEN_KEY, token);
    } catch {
      // Not remembered: the next login asks for the SMS again.
    }
  },
};

/**
 * What the person reads when a call fails: a wrong password in plain words, otherwise the backend's own Mongolian
 * `message` (each panel's ApiError carries `status` + `message`), else the panel's generic sentence.
 */
export function loginErrorMessage(e: unknown, genericError: string): string {
  if (!e || typeof e !== "object" || !("status" in e)) return genericError;
  const { status, message } = e as { status?: unknown; message?: unknown };
  if (status === 401) return CONSOLE_LOGIN_COPY.wrongCredentials;
  return typeof message === "string" && message.trim() ? message : genericError;
}

/** After the password: the SMS to send, and where its check stands. */
export interface SmsStep {
  challenge: ConsoleTwoStep;
  status: SmsVerificationStatus;
}

export interface UseConsoleLoginOptions<U extends { role: string }> {
  api: ConsoleLoginApi<U>;
  /** The one role this panel admits. */
  role: ConsoleRole;
  /** Shown when the account belongs to the other console (or is a viewer). */
  notRoleMessage: string;
  /** The panel's generic error sentence. */
  genericError: string;
  /** Store the session and leave the login page. */
  onSignedIn: (res: SignedIn<U>) => void;
}

export interface ConsoleLogin {
  phone: string;
  /** Keeps only the 8 digits. */
  setPhone: (raw: string) => void;
  password: string;
  setPassword: (value: string) => void;
  loading: boolean;
  error: string | null;
  notice: string | null;
  sms: SmsStep | null;
  submit: (e: FormEvent) => Promise<void>;
  newCode: () => Promise<void>;
  back: () => void;
}

/**
 * Pattern: Custom hook — the whole console login as state: the password step (with this browser's device token),
 * the SMS step when the backend asks for it, polling, a new code after expiry, and storing the new device token.
 */
export function useConsoleLogin<U extends { role: string }>(
  options: UseConsoleLoginOptions<U>,
): ConsoleLogin {
  // The latest options, so the polling effect does not restart when a page passes new callbacks each render.
  const latest = useRef(options);
  useEffect(() => {
    latest.current = options;
  });

  const [phone, setPhoneValue] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [sms, setSms] = useState<SmsStep | null>(null);

  const setPhone = useCallback((raw: string) => setPhoneValue(sanitizePhone(raw)), []);

  /** Proves the password; the right account is then signed in or gets the SMS step. */
  const passwordStep = async (): Promise<boolean> => {
    const { api, role, notRoleMessage, genericError, onSignedIn } = latest.current;
    try {
      const deviceToken = deviceTokenStore.get();
      const res = await api.login({
        phoneNumber: phone,
        password,
        ...(deviceToken ? { deviceToken } : {}),
      });
      if (isTwoStep(res)) {
        if (res.twoStep.role !== role) {
          setError(notRoleMessage);
          return false;
        }
        setSms({ challenge: res.twoStep, status: "PENDING" });
        return true;
      }
      if (res.user.role !== role) {
        setError(notRoleMessage);
        return false;
      }
      onSignedIn(res);
      return true;
    } catch (e) {
      setError(loginErrorMessage(e, genericError));
      return false;
    }
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (phone.length < 8 || password.length < 6) {
      setError(CONSOLE_LOGIN_COPY.checkForm);
      return;
    }
    setLoading(true);
    await passwordStep();
    setLoading(false);
  };

  const newCode = async () => {
    setError(null);
    setNotice(null);
    setLoading(true);
    if (await passwordStep()) setNotice(CONSOLE_LOGIN_COPY.newCodeReady);
    setLoading(false);
  };

  const back = () => {
    setSms(null);
    setError(null);
    setNotice(null);
    setPassword("");
  };

  const verificationId = sms?.challenge.verificationId ?? null;
  const expiresAt = sms?.challenge.expiresAt ?? null;
  const waiting = sms?.status === "PENDING";

  // Polls the check while it waits for the SMS; once confirmed, spends it for the token and the device token.
  useEffect(() => {
    if (!waiting || !verificationId || !expiresAt) return;
    let stopped = false;
    const setStatus = (status: SmsVerificationStatus) =>
      setSms((prev) =>
        prev && prev.challenge.verificationId === verificationId ? { ...prev, status } : prev,
      );
    const finish = async () => {
      const { api, role, notRoleMessage, genericError, onSignedIn } = latest.current;
      try {
        const res = await api.verify({ phoneNumber: phone, verificationId });
        if (stopped) return;
        if (res.user.role !== role) {
          setError(notRoleMessage);
          return;
        }
        deviceTokenStore.set(res.deviceToken);
        onSignedIn({ token: res.token, user: res.user });
      } catch (e) {
        if (stopped) return;
        setError(loginErrorMessage(e, genericError));
        setStatus("EXPIRED");
      }
    };
    const poll = async () => {
      if (hasRunOut(expiresAt, Date.now())) {
        setStatus("EXPIRED");
        return;
      }
      try {
        const state = await latest.current.api.phoneCheck(verificationId);
        if (stopped || state.status === "PENDING") return;
        setStatus(state.status);
        if (state.status === "VERIFIED") await finish();
      } catch {
        // A failed poll (network, server busy) is simply tried again on the next tick.
      }
    };
    const timer = window.setInterval(poll, CONSOLE_LOGIN_POLL_MS);
    return () => {
      stopped = true;
      window.clearInterval(timer);
    };
  }, [waiting, verificationId, expiresAt, phone]);

  return {
    phone,
    setPhone,
    password,
    setPassword,
    loading,
    error,
    notice,
    sms,
    submit,
    newCode,
    back,
  };
}
