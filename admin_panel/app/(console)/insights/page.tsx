"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Database, ListChecks, Percent, UserCheck } from "lucide-react";
import { PageHeader, SegmentedControl, StatCard } from "@uziy/ui";
import {
  ApiError,
  auth,
  insightsApi,
  type AccessLogEntry,
  type InsightQuestion,
  type InsightsOverview,
} from "@/lib/api";
import { AccessLogTable } from "@/components/insights/access-log-table";
import { GroupCard } from "@/components/insights/group-card";
import { PrivacyRulesCard } from "@/components/insights/privacy-rules-card";
import { QuestionExplorer } from "@/components/insights/question-explorer";

type Tab = "overview" | "questions" | "log";

const TABS = [
  { value: "overview" as const, label: "Самбар" },
  { value: "questions" as const, label: "Асуултууд" },
  { value: "log" as const, label: "Хандалтын бүртгэл" },
];

/**
 * Anonymous statistics across every survey, for selling aggregate insights
 * later. Super admin only; every view is logged (data_access_log).
 */
export default function InsightsPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>("overview");
  const [overview, setOverview] = useState<InsightsOverview | null>(null);
  const [questions, setQuestions] = useState<InsightQuestion[] | null>(null);
  const [log, setLog] = useState<AccessLogEntry[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    const fail = (e: unknown) => {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        auth.clear();
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Алдаа гарлаа");
    };
    insightsApi.overview().then(setOverview).catch(fail);
    insightsApi.questions().then(setQuestions).catch(fail);
  }, [router]);

  useEffect(() => {
    if (tab !== "log") return;
    insightsApi
      .accessLog()
      .then(setLog)
      .catch((e) => setError(e instanceof Error ? e.message : "Алдаа гарлаа"));
  }, [tab]);

  const k = overview?.minGroupSize ?? 50;
  return (
    <>
      <PageHeader
        title="Статистик"
        description="Бүх судалгааны нэргүй, нэгтгэсэн үр дүн — зөвхөн зөвшөөрсөн хэрэглэгчдээс"
      />

      {error && (
        <div
          role="alert"
          className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]"
        >
          {error}
        </div>
      )}

      <SegmentedControl label="Хэсэг" options={TABS} value={tab} onChange={setTab} className="mb-6" />

      {tab === "overview" && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
            <StatCard
              label="Нийт хэрэглэгч"
              value={overview ? overview.viewers.toLocaleString("en-US") : "—"}
              icon={<Database size={16} />}
            />
            <StatCard
              label="Зөвшөөрсөн"
              value={overview ? overview.consentingViewers.toLocaleString("en-US") : "—"}
              icon={<UserCheck size={16} />}
              hint="Статистикт оролцохыг зөвшөөрсөн"
            />
            <StatCard
              label="Зөвшөөрлийн хувь"
              value={overview ? `${overview.consentPercent}%` : "—"}
              icon={<Percent size={16} />}
            />
            <StatCard
              label="Тайлагнах асуулт"
              value={overview ? String(overview.reportableQuestions) : "—"}
              icon={<ListChecks size={16} />}
              hint={`${k}+ хариулттай`}
            />
          </div>
          {overview && (
            <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
              <GroupCard title="Хүйс" groups={overview.byGender} minGroupSize={k} />
              <GroupCard title="Насны бүлэг" groups={overview.byAgeBand} minGroupSize={k} />
              <GroupCard title="Аймаг / хот" groups={overview.byCity} minGroupSize={k} />
            </div>
          )}
          <PrivacyRulesCard minGroupSize={k} />
        </div>
      )}

      {tab === "questions" && (
        <QuestionExplorer
          questions={questions ?? []}
          ageBands={overview?.byAgeBand.map((g) => g.label) ?? []}
          cities={overview?.byCity.map((g) => g.label) ?? []}
          minGroupSize={k}
        />
      )}

      {tab === "log" && <AccessLogTable entries={log ?? []} />}
    </>
  );
}
