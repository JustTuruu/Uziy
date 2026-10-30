import { useRouter } from "@shared/navigation";
import { useEffect, useState } from "react";
import { MAX_DAYS } from "./analytics";
import { ApiError, GENERIC_ERROR_MESSAGE, analyticsApi, auth, type AnalyticsReport } from "./api";

export type CampaignResults =
  | { status: "idle" | "loading" }
  | { status: "ready"; report: AnalyticsReport }
  | { status: "error"; message: string };

type Settled = { key: string } & ({ report: AnalyticsReport } | { message: string });

/**
 * Pattern: Custom hook — loads one campaign's question results from `GET /company/analytics`, with a retry.
 * The window is the widest the backend allows; question and segment results ignore it and cover the
 * campaign's whole life. A refused token signs the company out, like every other page.
 */
export function useCampaignResults(campaignId: number | null): CampaignResults & { retry: () => void } {
  const router = useRouter();
  const [attempt, setAttempt] = useState(0);
  const [settled, setSettled] = useState<Settled | null>(null);
  const key = `${campaignId}|${attempt}`;

  useEffect(() => {
    if (campaignId === null) return;
    let cancelled = false;
    analyticsApi
      .get({ days: MAX_DAYS, campaignId })
      .then((report) => {
        if (!cancelled) setSettled({ key, report });
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setSettled({ key, message: e instanceof Error && e.message ? e.message : GENERIC_ERROR_MESSAGE });
      });
    return () => {
      cancelled = true;
    };
  }, [campaignId, key, router]);

  const retry = () => setAttempt((n) => n + 1);
  if (campaignId === null) return { status: "idle", retry };
  if (settled?.key !== key) return { status: "loading", retry };
  return "report" in settled
    ? { status: "ready", report: settled.report, retry }
    : { status: "error", message: settled.message, retry };
}
