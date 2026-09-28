import Link from "next/link";
import {
  AlertTriangle,
  Banknote,
  PlaySquare,
  TrendingUp,
  UserPlus,
  Users,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import {
  mockCampaigns,
  mockPayouts,
  platformStats,
} from "@/lib/mock-data";
import { formatNumber, formatTugrik, relativeTime } from "@/lib/utils";

export default function AdminDashboard() {
  const commissionAllTime = Math.round(
    platformStats.totalGmv * platformStats.commissionRate,
  );
  const pendingCampaigns = mockCampaigns.filter(
    (c) => c.status === "PENDING",
  );
  const pendingPayouts = mockPayouts.filter((p) => p.status === "PENDING");

  return (
    <>
      <PageHeader
        title="Супер Админы самбар"
        description="Платформын нийт статистик болон анхаарал шаардсан ажлууд"
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Нийт хэрэглэгч"
          value={formatNumber(platformStats.totalUsers)}
          icon={<Users size={16} />}
          trend={{ direction: "up", value: "+8%" }}
          hint="Энэ сар"
        />
        <StatCard
          label="7 хоногийн идэвх"
          value={formatNumber(platformStats.activeUsers7d)}
          icon={<UserPlus size={16} />}
          trend={{ direction: "up", value: "+14%" }}
        />
        <StatCard
          label="Нийт GMV"
          value={formatTugrik(platformStats.totalGmv)}
          icon={<TrendingUp size={16} />}
          hint="Компаниудын нийт зарцуулалт"
        />
        <StatCard
          label="Шимтгэлийн орлого"
          value={formatTugrik(commissionAllTime)}
          icon={<Banknote size={16} />}
          hint={`${Math.round(platformStats.commissionRate * 100)}% шимтгэл`}
        />
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader
            title="Хүлээгдэж буй мөнгө татах хүсэлт"
            description="Дансны нэрийг регистртэй тулгана"
            action={
              <Link
                href="/admin/payouts"
                className="text-xs font-semibold text-[var(--color-primary)] hover:underline"
              >
                Бүгд →
              </Link>
            }
          />
          <CardBody className="space-y-3">
            {pendingPayouts.length === 0 && (
              <div className="text-sm text-[var(--color-text-muted)]">
                Хүлээгдэж буй хүсэлт байхгүй.
              </div>
            )}
            {pendingPayouts.slice(0, 4).map((p) => (
              <Link
                key={p.id}
                href="/admin/payouts"
                className="flex items-center justify-between rounded-lg p-2 hover:bg-[var(--color-surface-elevated)]"
              >
                <div className="min-w-0">
                  <div className="flex items-center gap-2">
                    <div className="truncate text-sm font-semibold">
                      {p.accountName}
                    </div>
                    {p.isFirstPayout && (
                      <Badge tone="warning" className="shrink-0">
                        Эхний
                      </Badge>
                    )}
                  </div>
                  <div className="truncate text-xs text-[var(--color-text-muted)]">
                    {p.bank} · {p.userPhone} · {relativeTime(p.requestedAt)}
                  </div>
                </div>
                <div className="ml-4 shrink-0 font-mono text-sm font-bold text-[var(--color-primary)]">
                  {formatTugrik(p.amount)}
                </div>
              </Link>
            ))}
          </CardBody>
        </Card>

        <Card>
          <CardHeader
            title="Модераци хүлээж буй кампани"
            description="Видео контент, зорилтот тохиргоог шалгах"
            action={
              <Link
                href="/admin/campaigns"
                className="text-xs font-semibold text-[var(--color-primary)] hover:underline"
              >
                Бүгд →
              </Link>
            }
          />
          <CardBody className="space-y-3">
            {pendingCampaigns.length === 0 && (
              <div className="text-sm text-[var(--color-text-muted)]">
                Модераци хүлээж буй кампани байхгүй.
              </div>
            )}
            {pendingCampaigns.slice(0, 4).map((c) => (
              <Link
                key={c.id}
                href="/admin/campaigns"
                className="flex items-center justify-between rounded-lg p-2 hover:bg-[var(--color-surface-elevated)]"
              >
                <div className="flex min-w-0 items-center gap-3">
                  <div className="flex h-8 w-12 shrink-0 items-center justify-center rounded-md bg-gradient-to-br from-[#2c2c38] to-[#17171e]">
                    <PlaySquare size={12} className="text-white/70" />
                  </div>
                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold">
                      {c.title}
                    </div>
                    <div className="truncate text-xs text-[var(--color-text-muted)]">
                      {c.companyName} · {formatTugrik(c.totalBudget)} төсөв
                    </div>
                  </div>
                </div>
                <AlertTriangle
                  size={16}
                  className="ml-4 shrink-0 text-[var(--color-warning)]"
                />
              </Link>
            ))}
          </CardBody>
        </Card>
      </div>
    </>
  );
}
