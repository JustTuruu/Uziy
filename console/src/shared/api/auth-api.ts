import type {
  ConsoleLoginBody,
  ConsoleLoginResult,
  PhoneCheck,
  VerifiedLogin,
} from "@uziy/ui";
import { apiFetch } from "./http";
import type { Me } from "./types";

/** `POST /auth/login`: a token (200), or on a browser the server does not recognise the SMS step (202). */
export type LoginResult = ConsoleLoginResult<Me>;

/** The `ConsoleLoginApi` the shared login flow (`@uziy/ui` useConsoleLogin) calls; companies and admins alike. */
export const authApi = {
  login: (body: ConsoleLoginBody) =>
    apiFetch<LoginResult>("/auth/login", {
      method: "POST",
      body,
      anonymous: true,
    }),
  phoneCheck: (verificationId: string) =>
    apiFetch<PhoneCheck>(`/auth/phone-verifications/${encodeURIComponent(verificationId)}`, {
      anonymous: true,
    }),
  /** Finishes the SMS step: the token, plus this browser's device token. */
  verify: (body: { phoneNumber: string; verificationId: string }) =>
    apiFetch<VerifiedLogin<Me>>("/auth/login/verify", {
      method: "POST",
      body,
      anonymous: true,
    }),
};
