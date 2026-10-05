"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
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
  ApiError,
  adminApi,
  auth,
  platformSettingsApi,
  type AdminStats,
  type Campaign,
  type Payout,
  type PlatformSettings,
} from "@/lib/api";
import { formatNumber, formatTugrik, relativeTime } from "@/lib/utils";

export default function AdminDashboard() {
  const router = useRouter();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [pendingCampaigns, setPendingCampaigns] = useState<Campaign[]>([]);
  const [pendingPayouts, setPendingPayouts] = useState<Payout[]>([]);
  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    (async () => {
      try {
        const [s, camps, payouts, ps] = await Promise.all([
          adminApi.stats(),
          adminApi.campaigns({ status: "PENDING" }),
          adminApi.pendingPayouts(),
          // The commission the admin actually set; optional so a hiccup
          // here doesn't blank the whole dashboard.
          platformSettingsApi.get().catch(() => null),
        ]);
        setStats(s);
        setSettings(ps);
        setPendingCampaigns(camps);
        setPendingPayouts(payouts);
      } catch (e) {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      }
    })();
  }, [router]);

  if (error) {
    return (
      <div className="rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] p-6 text-sm text-[var(--color-danger)]">
        Серверээс мэдээлэл авч чадсангүй: {error}
      </div>
    );
  }

  if (!stats) {
    return (
      <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
        Ачаалж байна...
      </div>
    );
  }

  return (
    <>
      <PageHeader
        title="Супер Админы самбар"
        description="Платформын нийт статистик болон анхаарал шаардсан ажлууд"
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Нийт хэрэглэгч"
          value={formatNumber(stats.totalUsers)}
          icon={<Users size={16} />}
        />
        <StatCard
          label="Идэвхтэй кампани"
          value={formatNumber(stats.activeCampaigns)}
          icon={<TrendingUp size={16} />}
        />
        <StatCard
          label="Шимтгэлийн хувь"
          value={`${settings?.commissionPercent ?? Math.round(stats.commissionRate * 100)}%`}
          icon={<Banknote size={16} />}
          hint={
            <Link
              href="/pricing"
              className="hover:text-[var(--color-text-primary)] hover:underline"
            >
              Аяны төсвөөс · тохируулах
            </Link>
          }
        />
        <StatCard
          label="Хүлээгдэж буй"
          value={formatNumber(
            stats.pendingCampaigns + stats.pendingPayouts,
          )}
          icon={<UserPlus size={16} />}
          hint={`${stats.pendingCampaigns} кампани · ${stats.pendingPayouts} татах`}
        />
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <CardHeader
            title="Хүлээгдэж буй мөнгө татах хүсэлт"
            description="Дансны нэрийг регистртэй тулгана"
            action={
              <Link
                href="/payouts"
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
              <div
                key={p.id}
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
              </div>
            ))}
          </CardBody>
        </Card>

        <Card>
          <CardHeader
            title="Модераци хүлээж буй кампани"
            description="Видео контент, зорилтот тохиргоог шалгах"
            action={
              <Link
                href="/campaigns"
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
              <div
                key={c.id}
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
                      {formatTugrik(c.totalBudget)} төсөв
                    </div>
                  </div>
                </div>
                <AlertTriangle
                  size={16}
                  className="ml-4 shrink-0 text-[var(--color-warning)]"
                />
              </div>
            ))}
          </CardBody>
        </Card>
      </div>
    </>
  );
}
