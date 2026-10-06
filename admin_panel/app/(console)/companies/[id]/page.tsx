"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ArrowLeft,
  Building2,
  ClipboardList,
  Play,
  ShieldCheck,
  TrendingUp,
  Users,
  Wallet,
} from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Badge, Card, CardBody, CardHeader, PageHeader, StatCard } from "@uziy/ui";
import {
  adminApi,
  ApiError,
  auth,
  type AdminUser,
  type Campaign,
} from "@/lib/api";
import { summarizeCampaignBudgets } from "@/lib/billing";
import { formatTugrik, relativeTime } from "@/lib/utils";

export default function AdminCompanyDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [user, setUser] = useState<AdminUser | null>(null);
  const [campaigns, setCampaigns] = useState<Campaign[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    if (!Number.isFinite(id)) return; // shown as `invalidId` below
    (async () => {
      try {
        const [u, c] = await Promise.all([
          adminApi.user(id),
          adminApi.campaigns({ companyId: id }),
        ]);
        setUser(u);
        setCampaigns(c);
      } catch (e) {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        if (e instanceof ApiError && e.status === 404) {
          setError("Компани олдсонгүй");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      }
    })();
  }, [id, router]);

  const invalidId = !Number.isFinite(id);
  const shownError = invalidId ? "ID буруу" : error;

  if (shownError) {
    return (
      <>
        <BackLink />
        <Card>
          <CardBody className="py-10 text-center text-sm text-[var(--color-danger)]">
            {shownError}
          </CardBody>
        </Card>
      </>
    );
  }

  if (!user || !campaigns) {
    return (
      <>
        <BackLink />
        <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
          Ачаалж байна...
        </div>
      </>
    );
  }

  if (user.role !== "COMPANY") {
    return (
      <>
        <BackLink />
        <Card>
          <CardBody className="py-10 text-center text-sm text-[var(--color-text-muted)]">
            Энэ хэрэглэгч компани биш байна. (role={user.role})
          </CardBody>
        </Card>
      </>
    );
  }

  const pendingCount = campaigns.filter((c) => c.status === "PENDING").length;
  // Unpaid campaigns are excluded from spent/remaining.
  const { activeCount, totalSpent, totalRemaining } =
    summarizeCampaignBudgets(campaigns);

  return (
    <>
      <BackLink />

      <PageHeader
        title={user.companyName ?? "Нэргүй компани"}
        description={`${user.phoneNumber} · Бүртгэсэн: ${relativeTime(user.createdAt)}`}
        actions={
          <Badge tone={user.isVerified ? "success" : "neutral"}>
            {user.isVerified ? (
              <span className="inline-flex items-center gap-1">
                <ShieldCheck size={12} /> Баталгаажсан
              </span>
            ) : (
              "Баталгаажаагүй"
            )}
          </Badge>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Идэвхтэй кампани"
          value={String(activeCount)}
          icon={<Play size={16} />}
        />
        <StatCard
          label="Модераци хүлээж буй"
          value={String(pendingCount)}
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
          icon={<Wallet size={16} />}
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title={`Кампаниуд (${campaigns.length})`}
            description="Энэ компанийн бүх кампани, шинэ нь эхэнд"
          />
          <CardBody className="p-0">
            {campaigns.length === 0 ? (
              <div className="py-16 text-center text-sm text-[var(--color-text-muted)]">
                <Building2 size={20} className="mx-auto mb-2" />
                Энэ компани кампани үүсгээгүй байна.
              </div>
            ) : (
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
                  {campaigns.map((c) => (
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
                              <Play size={14} className="text-white/70" />
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
                              {relativeTime(c.createdAt)}
                            </div>
                          </div>
                        </Link>
                      </td>
                      <td className="px-5 py-4 text-xs text-[var(--color-text-secondary)]">
                        {c.hasVideo ? "Видеотой" : "Судалгаа зөвхөн"}
                      </td>
                      <td className="px-5 py-4">
                        <CampaignStatusBadge status={c.status} />
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

function BackLink() {
  return (
    <Link
      href="/users"
      className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
    >
      <ArrowLeft size={12} /> Хэрэглэгчид
    </Link>
  );
}
