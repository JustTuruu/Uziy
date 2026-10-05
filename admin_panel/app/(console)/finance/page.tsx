"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Banknote, PiggyBank, TrendingUp } from "lucide-react";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import {
  adminApi,
  ApiError,
  auth,
  platformSettingsApi,
  type AdminStats,
  type PlatformSettings,
} from "@/lib/api";

export default function FinancePage() {
  const router = useRouter();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    platformSettingsApi
      .get()
      .then(setSettings)
      .catch(() => setSettings(null));
    adminApi
      .stats()
      .then(setStats)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  return (
    <>
      <PageHeader
        title="Санхүү"
        description="Платформын нийт орлого болон хэрэглэгчид олгосон урамшуулал"
      />

      {error && (
        <div className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]">
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <StatCard
          label="Идэвхтэй кампани"
          value={stats ? String(stats.activeCampaigns) : "—"}
          icon={<TrendingUp size={16} />}
          hint="Одоо хэрэглэгчдэд харагдаж байгаа"
        />
        <StatCard
          label="Шимтгэлийн хувь"
          value={
            settings
              ? `${settings.commissionPercent}%`
              : stats
                ? `${Math.round(stats.commissionRate * 100)}%`
                : "—"
          }
          icon={<Banknote size={16} />}
          hint="Аяны төсвөөс"
        />
        <StatCard
          label="Хүлээгдэж буй таталт"
          value={stats ? String(stats.pendingPayouts) : "—"}
          icon={<PiggyBank size={16} />}
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Сар бүрийн жагсаалт"
            description="Backend-д /admin/finance/monthly endpoint нэмэгдэх хүртэл хоосон"
          />
          <CardBody className="py-16 text-center text-sm text-[var(--color-text-muted)]">
            Сарын GMV, шимтгэл, олгосон дүнгийн тайлан удахгүй нээгдэнэ.
          </CardBody>
        </Card>
      </div>
    </>
  );
}
