/** Where the call-to-action buttons lead; every URL is deploy-time config. */
export interface SiteLinks {
  /** App Store listing, or null until the app is published. */
  appStore: string | null;
  /** Google Play listing, or null until the app is published. */
  playStore: string | null;
  /** Company panel, where companies log in (Uziy creates their accounts). */
  companyPanel: string;
  /** Where a company asks for an account (mailto), or null when not configured — never a made-up address. */
  contactEmail: string | null;
}

export const DEFAULT_COMPANY_PANEL_URL = "http://localhost:3000";

type Env = Record<string, string | undefined>;

/** Blank values count as "not set" so an empty `.env` line cannot make a dead link. */
function valueOrNull(value: string | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

export function resolveLinks(env: Env): SiteLinks {
  return {
    appStore: valueOrNull(env.NEXT_PUBLIC_APP_STORE_URL),
    playStore: valueOrNull(env.NEXT_PUBLIC_PLAY_STORE_URL),
    companyPanel:
      valueOrNull(env.NEXT_PUBLIC_COMPANY_PANEL_URL) ??
      DEFAULT_COMPANY_PANEL_URL,
    contactEmail: valueOrNull(env.NEXT_PUBLIC_CONTACT_EMAIL),
  };
}

export const siteLinks: SiteLinks = resolveLinks({
  NEXT_PUBLIC_APP_STORE_URL: process.env.NEXT_PUBLIC_APP_STORE_URL,
  NEXT_PUBLIC_PLAY_STORE_URL: process.env.NEXT_PUBLIC_PLAY_STORE_URL,
  NEXT_PUBLIC_COMPANY_PANEL_URL: process.env.NEXT_PUBLIC_COMPANY_PANEL_URL,
  NEXT_PUBLIC_CONTACT_EMAIL: process.env.NEXT_PUBLIC_CONTACT_EMAIL,
});
