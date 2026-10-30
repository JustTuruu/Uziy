"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Coins, MessageSquareText, Wallet, Zap } from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { BarChart, PointsTable } from "@/components/bar-chart";
import { InsightsCard } from "@/components/insights-card";
import { DistributionBars } from "@/components/distribution-bars";
import { RESULTS_WHOLE_LIFE, SurveyResults } from "@/components/survey-results";
import { Button, Card, CardBody, CardHeader, PageHeader, SegmentedControl, Select, StatCard, TableScroll } from "@uziy/ui";
import {
  DAY_OPTIONS,
  DEFAULT_DAYS,
  MIN_AUDIENCE_SAMPLE,
  SMALL_GROUPS_HIDDEN,
  audienceBase,
  buildInsights,
  dailyPoints,
  formatPercent,
  genderLabel,
  peakDay,
} from "@/lib/analytics";
import { ApiError, analyticsApi, auth, type AnalyticsReport } from "@/lib/api";
import { formatNumber, formatTugrik } from "@/lib/utils";

const ALL_CAMPAIGNS = "";

/** A fetched report together with the filter it answers, so a stale one is never shown for a new filter. */
interface Loaded {
  key: string;
  report: AnalyticsReport;
}

export default function AnalyticsPage() {
  const router = useRouter();
  const [days, setDays] = useState<string>(DEFAULT_DAYS);
  const [campaignId, setCampaignId] = useState<string>(ALL_CAMPAIGNS);
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const [failure, setFailure] = useState<{
    key: string;
    message: string;
  } | null>(null);
  const [showTable, setShowTable] = useState(false);

  const key = `${days}|${campaignId}`;

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    let cancelled = false;
    analyticsApi
      .get({
        days: Number(days),
        campaignId:
          campaignId === ALL_CAMPAIGNS ? undefined : Number(campaignId),
      })
      .then((report) => {
        if (!cancelled) setLoaded({ key, report });
      })
      .catch((e) => {
        if (cancelled) return;
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setFailure({
          key,
          message: e instanceof Error ? e.message : "Алдаа гарлаа",
        });
      });
    return () => {
      cancelled = true;
    };
  }, [days, campaignId, key, router]);

  // Totals and the campaign list do not depend on the filter, so keep the
  // last report on screen while a new one loads instead of flashing empty.
  const report = loaded?.report ?? null;
  const loading = loaded?.key !== key && failure?.key !== key;
  const error = failure?.key === key ? failure.message : null;
  const selected =
    report?.campaigns.find((c) => String(c.campaignId) === campaignId) ?? null;
  const campaignOptions = [
    { value: ALL_CAMPAIGNS, label: "Бүх судалгаа" },
    ...(report?.campaigns ?? []).map((c) => ({
      value: String(c.campaignId),
      label: c.title,
    })),
  ];

  return (
    <>
      <PageHeader
        title="Тайлан"
        description="Судалгааны гүйцэтгэлийн харьцуулсан тайлан"
        actions={
          <div className="flex flex-wrap items-center gap-3">
            <Select
              aria-label="Судалгаа сонгох"
              options={campaignOptions}
              value={campaignId}
              onValueChange={setCampaignId}
            />
            <SegmentedControl
              label="Хугацаа"
              options={DAY_OPTIONS}
              value={days as (typeof DAY_OPTIONS)[number]["value"]}
              onChange={setDays}
            />
          </div>
        }
      />

      {error && (
        <div
          role="alert"
          className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]"
        >
          {error}
        </div>
      )}

      {report === null && !error && (
        <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
          Ачаалж байна...
        </div>
      )}

      {report && report.campaigns.length === 0 && (
        <Card>
          <CardBody className="py-16 text-center text-sm text-[var(--color-text-muted)]">
            Судалгаа байхгүй байна.{" "}
            <Link
              href="/campaigns/new"
              className="text-[var(--color-primary)] hover:underline"
            >
              Шинэ судалгаа
            </Link>{" "}
            үүсгээд хариулт цуглуулж эхлээрэй.
          </CardBody>
        </Card>
      )}

      {report && report.campaigns.length > 0 && (
        <div
          className={
            loading ? "opacity-60 transition-opacity" : "transition-opacity"
          }
        >
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
            <StatCard
              label="Нийт хариулт"
              value={formatNumber(report.totals.responses)}
              hint={`${report.totals.activeCount} идэвхтэй / ${report.totals.campaignCount} судалгаа`}
              icon={<MessageSquareText size={16} />}
            />
            <StatCard
              label="Зарцуулсан"
              value={formatTugrik(report.totals.spent)}
              icon={<Wallet size={16} />}
            />
            <StatCard
              label="Хариулт тутмын өртөг"
              value={
                report.totals.costPerResponse === null
                  ? "—"
                  : formatTugrik(report.totals.costPerResponse)
              }
              icon={<Zap size={16} />}
            />
            <StatCard
              label="Үзэгчдэд олгосон"
              value={formatTugrik(report.totals.rewardsPaid)}
              icon={<Coins size={16} />}
            />
          </div>

          <div className="mt-8">
            <InsightsCard
              insights={buildInsights(
                report,
                selected ? selected.campaignId : null,
              )}
            />
          </div>

          <div className="mt-8">
            <Card>
              <CardHeader
                title="Өдөр тутмын хариулт"
                description={selected ? selected.title : "Бүх судалгаа"}
                action={
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowTable((v) => !v)}
                  >
                    {showTable ? "График" : "Хүснэгт"}
                  </Button>
                }
              />
              <CardBody>
                {report.daily.every((d) => d.responses === 0) ? (
                  <p className="py-10 text-center text-sm text-[var(--color-text-muted)]">
                    Энэ хугацаанд хариулт ирээгүй байна.
                  </p>
                ) : showTable ? (
                  <PointsTable
                    points={dailyPoints(report.daily)}
                    heading="Огноо"
                    valueHeading="Хариулт"
                    newestFirst
                  />
                ) : (
                  <>
                    <BarChart
                      points={dailyPoints(report.daily)}
                      ariaLabel="Өдөр тутмын хариултын тоо"
                      noun="хариулт"
                    />
                    <PeakNote daily={report.daily} />
                  </>
                )}
              </CardBody>
            </Card>
          </div>

          <div className="mt-8">
            <Card>
              <CardHeader
                title="Судалгаануудын харьцуулалт"
                description="Аль судалгаа хамгийн хямд, хамгийн их хариулт авч байна"
              />
              <CardBody className="p-0">
                <div className="overflow-x-auto">
                  <TableScroll>
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                          <th className="px-5 py-3 font-semibold">Судалгаа</th>
                          <th className="px-5 py-3 font-semibold">Төлөв</th>
                          <th className="px-5 py-3 text-right font-semibold">
                            Хариулт
                          </th>
                          <th className="px-5 py-3 font-semibold">Хүрэлт</th>
                          <th className="px-5 py-3 text-right font-semibold">
                            Зарцуулсан
                          </th>
                          <th className="px-5 py-3 text-right font-semibold">
                            Өртөг / хариулт
                          </th>
                          <th className="px-5 py-3 text-right font-semibold">
                            Бюджет дуусах
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {report.campaigns.map((c) => (
                          <tr
                            key={c.campaignId}
                            className="border-b border-[var(--color-divider)] last:border-0 hover:bg-[var(--color-surface-elevated)]/60"
                          >
                            <td className="px-5 py-4">
                              <button
                                type="button"
                                onClick={() =>
                                  setCampaignId(String(c.campaignId))
                                }
                                className="text-left font-semibold text-[var(--color-text-primary)] hover:text-[var(--color-primary)]"
                              >
                                {c.title}
                              </button>
                              <div className="text-xs text-[var(--color-text-muted)]">
                                {c.hasVideo ? "Видеотой" : "Судалгаа зөвхөн"}
                              </div>
                            </td>
                            <td className="px-5 py-4">
                              <CampaignStatusBadge status={c.status} />
                            </td>
                            <td className="px-5 py-4 text-right font-mono tabular-nums">
                              {formatNumber(c.responses)}
                              {c.targetViewers !== null && (
                                <span className="text-[var(--color-text-muted)]">
                                  {" "}
                                  / {formatNumber(c.targetViewers)}
                                </span>
                              )}
                            </td>
                            <td className="px-5 py-4">
                              <ReachBar percent={c.reachPercent} />
                            </td>
                            <td className="px-5 py-4 text-right font-mono tabular-nums">
                              {formatTugrik(c.spent)}
                            </td>
                            <td className="px-5 py-4 text-right font-mono tabular-nums">
                              {c.costPerResponse === null
                                ? "—"
                                : formatTugrik(c.costPerResponse)}
                            </td>
                            <td className="px-5 py-4 text-right text-xs text-[var(--color-text-secondary)]">
                              {c.daysLeft === null ? "—" : `~${c.daysLeft} хоног`}
                              <div className="text-[var(--color-text-muted)]">
                                {formatNumber(c.remainingResponses)} хариулт
                                үлдсэн
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </TableScroll>
                </div>
              </CardBody>
            </Card>
          </div>

          <div className="mt-8">
            <Card>
              <CardHeader
                title="Хариулсан үзэгчид"
                description={selected ? selected.title : "Бүх судалгаа"}
              />
              <CardBody>
                {report.audience === null ? (
                  <p className="py-6 text-center text-sm text-[var(--color-text-muted)]">
                    Хувь хүнийг таних боломжгүй байлгахын тулд дор хаяж{" "}
                    {MIN_AUDIENCE_SAMPLE} хариулт цугларсны дараа харуулна.
                  </p>
                ) : (
                  <>
                    <div className="grid grid-cols-1 gap-8 md:grid-cols-3">
                      <DistributionBars
                        title="Хүйс"
                        slices={report.audience.gender}
                        total={audienceBase(report, selected)}
                        formatLabel={genderLabel}
                        emptyText={SMALL_GROUPS_HIDDEN}
                      />
                      <DistributionBars
                        title="Нас"
                        slices={report.audience.ageBands}
                        total={audienceBase(report, selected)}
                        emptyText={SMALL_GROUPS_HIDDEN}
                      />
                      <DistributionBars
                        title="Хот"
                        slices={report.audience.cities}
                        total={audienceBase(report, selected)}
                        emptyText={SMALL_GROUPS_HIDDEN}
                      />
                    </div>
                    <p className="mt-6 text-xs text-[var(--color-text-muted)]">
                      {SMALL_GROUPS_HIDDEN} Хувийг нийт хариултаас тооцсон.
                    </p>
                  </>
                )}
              </CardBody>
            </Card>
          </div>

          {selected && (
            <div className="mt-8">
              <Card>
                <CardHeader
                  title="Асуултуудын хариулт"
                  description={`${selected.title} · ${RESULTS_WHOLE_LIFE} (хугацааны шүүлтүүрээс хамаарахгүй)`}
                />
                <CardBody>
                  <SurveyResults questions={report.questions} segments={report.segments} />
                </CardBody>
              </Card>
            </div>
          )}
        </div>
      )}
    </>
  );
}

function PeakNote({ daily }: { daily: AnalyticsReport["daily"] }) {
  const peak = peakDay(daily);
  if (!peak) return null;
  return (
    <p className="mt-2 text-xs text-[var(--color-text-muted)]">
      Хамгийн их: {peak.date} · {formatNumber(peak.responses)} хариулт
    </p>
  );
}

function ReachBar({ percent }: { percent: number | null }) {
  if (percent === null) {
    return <span className="text-xs text-[var(--color-text-muted)]">—</span>;
  }
  return (
    <div className="flex items-center gap-3">
      <div className="h-2 w-24 rounded-full bg-[var(--color-surface-elevated)]">
        <div
          className="h-2 rounded-full bg-[var(--color-primary)]"
          style={{ width: `${Math.min(100, percent)}%` }}
        />
      </div>
      <span className="w-12 font-mono text-xs tabular-nums text-[var(--color-text-secondary)]">
        {formatPercent(percent)}
      </span>
    </div>
  );
}
