"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ClipboardList,
  CreditCard,
  Eye,
  Play,
  Plus,
  TrendingUp,
  Users,
} from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Button, Card, CardBody, CardHeader, PageHeader, StatCard } from "@uziy/ui";
import {
  ApiError,
  auth,
  companyApi,
  useStoredUser,
  type Campaign,
} from "@/lib/api";
import { summarizeCampaignBudgets } from "@/lib/billing";
import { formatTugrik } from "@/lib/utils";

export default function CompanyDashboard() {
  const router = useRouter();
  const [campaigns, setCampaigns] = useState<Campaign[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    companyApi
      .list()
      .then(setCampaigns)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  // Unpaid (AWAITING_PAYMENT) campaigns are kept out of spent/remaining —
  // that money hasn't been paid yet.
  const {
    activeCount,
    awaitingPayment,
    awaitingPaymentTotal,
    totalSpent,
    totalRemaining,
  } = summarizeCampaignBudgets(campaigns ?? []);

  const me = useStoredUser();
  const companyName = me?.companyName ?? "Компани";

  return (
    <>
      <PageHeader
        title={`Сайн байна уу, ${companyName}`}
        description="Судалгаануудынхаа одоогийн байдлыг доорх самбарнаас харна уу."
        actions={
          <Link href="/campaigns/new">
            <Button leftIcon={<Plus size={16} />}>Шинэ судалгаа</Button>
          </Link>
        }
      />

      {error && (
        <div className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]">
          {error}
        </div>
      )}

      {awaitingPayment.length > 0 && (
        <div className="mb-6 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)] px-4 py-3 text-sm">
          <div className="flex items-center gap-2 text-[var(--color-text-primary)]">
            <CreditCard
              size={16}
              className="shrink-0 text-[var(--color-warning)]"
            />
            Төлбөр хүлээгдэж буй {awaitingPayment.length} аян байна ·{" "}
            <span className="font-mono font-semibold">
              {formatTugrik(awaitingPaymentTotal)}
            </span>
          </div>
          <Link
            href={
              awaitingPayment.length === 1
                ? `/campaigns/${awaitingPayment[0].id}`
                : "/billing"
            }
          >
            <Button size="sm">Төлөх</Button>
          </Link>
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Идэвхтэй кампани"
          value={String(activeCount)}
          icon={<Play size={16} />}
        />
        <StatCard
          label="Нийт кампани"
          value={String(campaigns?.length ?? 0)}
          icon={<Users size={16} />}
        />
        <StatCard
          label="Нийт зарцуулалт"
          value={formatTugrik(totalSpent)}
          icon={<TrendingUp size={16} />}
        />
        <StatCard
          label="Үлдэгдэл төсөв"
          value={formatTugrik(totalRemaining)}
          icon={<Eye size={16} />}
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Судалгаа"
            description="Таны бүх судалгаа"
            action={
              <Link href="/campaigns">
                <Button variant="ghost" size="sm">
                  Бүгд харах
                </Button>
              </Link>
            }
          />
          <CardBody className="p-0">
            {campaigns === null && !error && (
              <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            )}
            {campaigns && campaigns.length === 0 && (
              <div className="py-16 text-center text-sm text-[var(--color-text-muted)]">
                Кампани байхгүй. Эхлэхийн тулд{" "}
                <Link
                  href="/campaigns/new"
                  className="text-[var(--color-primary)] hover:underline"
                >
                  Шинэ судалгаа
                </Link>{" "}
                дараарай.
              </div>
            )}
            {campaigns && campaigns.length > 0 && (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                    <th className="px-5 py-3 font-semibold">Гарчиг</th>
                    <th className="px-5 py-3 font-semibold">Төрөл</th>
                    <th className="px-5 py-3 font-semibold">Төлөв</th>
                    <th className="px-5 py-3 font-semibold text-right">
                      Үлдэгдэл
                    </th>
                    <th className="px-5 py-3 font-semibold text-right">
                      Урамшуулал
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {campaigns.slice(0, 5).map((c) => (
                    <tr
                      key={c.id}
                      className="border-b border-[var(--color-divider)] last:border-0 hover:bg-[var(--color-surface-elevated)]/60"
                    >
                      <td className="px-5 py-4">
                        <Link
                          href={`/campaigns/${c.id}`}
                          className="flex items-center gap-3"
                        >
                          <div className="flex h-10 w-16 items-center justify-center rounded-md bg-gradient-to-br from-[#2c2c38] to-[#17171e]">
                            {c.hasVideo ? (
                              <Play
                                size={14}
                                className="text-white/70"
                                fill="currentColor"
                              />
                            ) : (
                              <ClipboardList
                                size={14}
                                className="text-white/70"
                              />
                            )}
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--color-text-primary)]">
                              {c.title}
                            </div>
                            <div className="text-xs text-[var(--color-text-muted)]">
                              {c.hasVideo
                                ? `${c.durationSeconds} сек`
                                : "Судалгаа"}
                              {" · "}
                              {c.targetCity === "ALL" ? "Бүх" : c.targetCity}
                            </div>
                          </div>
                        </Link>
                      </td>
                      <td className="px-5 py-4 text-xs text-[var(--color-text-secondary)]">
                        {c.hasVideo ? "Видеотой" : "Судалгаа зөвхөн"}
                      </td>
                      <td className="px-5 py-4">
                        <div className="flex items-center gap-2">
                          <CampaignStatusBadge status={c.status} />
                          {c.status === "AWAITING_PAYMENT" && (
                            <Link
                              href={`/campaigns/${c.id}`}
                              className="text-xs font-semibold text-[var(--color-primary)] hover:underline"
                            >
                              Төлөх
                            </Link>
                          )}
                        </div>
                      </td>
                      <td className="px-5 py-4 text-right">
                        <div className="font-mono text-[var(--color-text-primary)]">
                          {formatTugrik(c.remainingBudget)}
                        </div>
                        <div className="text-xs text-[var(--color-text-muted)]">
                          / {formatTugrik(c.totalBudget)}
                        </div>
                      </td>
                      <td className="px-5 py-4 text-right font-mono text-[var(--color-text-primary)]">
                        {formatTugrik(c.rewardPerUser)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </CardBody>
        </Card>
      </div>
    </>
  );
}
