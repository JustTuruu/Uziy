"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Check, ClipboardList, Play, X } from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { adminApi, ApiError, auth, type Campaign } from "@/lib/api";
import { formatTugrik, relativeTime } from "@/lib/utils";

export default function AdminCampaignsPage() {
  const router = useRouter();
  const [all, setAll] = useState<Campaign[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [decidingId, setDecidingId] = useState<number | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    adminApi
      .campaigns()
      .then(setAll)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  const decide = async (id: number, decision: "ACTIVE" | "REJECTED") => {
    setDecidingId(id);
    try {
      const updated = await adminApi.moderate(id, decision);
      setAll((prev) =>
        prev ? prev.map((c) => (c.id === id ? updated : c)) : prev,
      );
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Алдаа гарлаа");
    } finally {
      setDecidingId(null);
    }
  };

  const pending = (all ?? []).filter((c) => c.status === "PENDING");
  const others = (all ?? []).filter((c) => c.status !== "PENDING");

  return (
    <>
      <PageHeader
        title="Кампани модераци"
        description="Шинэ видео агуулга, зорилтот тохиргоог шалгаж баталгаажуулна"
      />

      {error && (
        <div className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]">
          {error}
        </div>
      )}

      <Card>
        <CardHeader
          title={
            all === null
              ? "Ачаалж байна..."
              : `Модераци хүлээж буй (${pending.length})`
          }
          description="Төлбөр нь төлөгдсөн аянууд. Видеог бүтэн үзэж, зорилтот бодлогод нийцэж байгаа эсэхийг шалгана"
        />
        <CardBody className="p-0">
          {all === null ? (
            <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
              Ачаалж байна...
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Кампани</th>
                  <th className="px-5 py-3 font-semibold">Зорилтот</th>
                  <th className="px-5 py-3 font-semibold text-right">Төсөв</th>
                  <th className="px-5 py-3 font-semibold text-right">Үйлдэл</th>
                </tr>
              </thead>
              <tbody>
                {pending.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]"
                    >
                      Модераци хүлээж буй кампани байхгүй.
                    </td>
                  </tr>
                )}
                {pending.map((c) => (
                  <tr
                    key={c.id}
                    className="border-b border-[var(--color-divider)] last:border-0 hover:bg-[var(--color-surface-elevated)]/60"
                  >
                    <td className="px-5 py-4">
                      <Link
                        href={`/admin/campaigns/${c.id}`}
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
                          <div className="font-semibold">{c.title}</div>
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
                      {c.targetGender === "ALL"
                        ? "Бүгд"
                        : c.targetGender === "MALE"
                          ? "Эрэгтэй"
                          : "Эмэгтэй"}{" "}
                      · {c.minAge}-{c.maxAge} нас ·{" "}
                      {c.targetCity === "ALL" ? "Бүх хот" : c.targetCity}
                    </td>
                    <td className="px-5 py-4 text-right">
                      <div className="font-mono text-[var(--color-text-primary)]">
                        {formatTugrik(c.totalBudget)}
                      </div>
                      <div className="text-xs text-[var(--color-text-muted)]">
                        {c.commissionPercent !== null &&
                          `${c.commissionPercent}% шимтгэл · `}
                        {c.paidAt
                          ? `Төлсөн ${relativeTime(c.paidAt)}`
                          : "Төлбөрийн огноогүй"}
                      </div>
                    </td>
                    <td className="px-5 py-4">
                      <div className="flex justify-end gap-2">
                        <Button
                          size="sm"
                          variant="secondary"
                          leftIcon={<X size={12} />}
                          onClick={() => decide(c.id, "REJECTED")}
                          disabled={decidingId === c.id}
                        >
                          Татгалзах
                        </Button>
                        <Button
                          size="sm"
                          variant="success"
                          leftIcon={<Check size={12} />}
                          onClick={() => decide(c.id, "ACTIVE")}
                          disabled={decidingId === c.id}
                        >
                          Баталгаажуулах
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </CardBody>
      </Card>

      {all !== null && (
        <Card className="mt-6">
          <CardHeader title={`Бусад (${others.length})`} />
          <CardBody className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Кампани</th>
                  <th className="px-5 py-3 font-semibold">Төлөв</th>
                  <th className="px-5 py-3 font-semibold text-right">Төсөв</th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Үлдэгдэл
                  </th>
                </tr>
              </thead>
              <tbody>
                {others.map((c) => (
                  <tr
                    key={c.id}
                    className="border-b border-[var(--color-divider)] last:border-0 hover:bg-[var(--color-surface-elevated)]/60"
                  >
                    <td className="px-5 py-3">
                      <Link
                        href={`/admin/campaigns/${c.id}`}
                        className="flex items-center gap-2"
                      >
                        {c.hasVideo ? (
                          <Play
                            size={12}
                            className="text-[var(--color-text-muted)]"
                          />
                        ) : (
                          <ClipboardList
                            size={12}
                            className="text-[var(--color-text-muted)]"
                          />
                        )}
                        <span>{c.title}</span>
                      </Link>
                    </td>
                    <td className="px-5 py-3">
                      <CampaignStatusBadge status={c.status} />
                    </td>
                    <td className="px-5 py-3 text-right font-mono">
                      {formatTugrik(c.totalBudget)}
                    </td>
                    <td className="px-5 py-3 text-right font-mono">
                      {formatTugrik(c.remainingBudget)}
                    </td>
                  </tr>
                ))}
                {others.length === 0 && (
                  <tr>
                    <td
                      colSpan={4}
                      className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]"
                    >
                      Өөр кампани байхгүй.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </CardBody>
        </Card>
      )}
    </>
  );
}
