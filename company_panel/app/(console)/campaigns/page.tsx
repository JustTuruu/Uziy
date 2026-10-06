"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ClipboardList, CreditCard, Play, Plus } from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Button, Card, CardBody, PageHeader } from "@uziy/ui";
import { ApiError, auth, companyApi, type Campaign } from "@/lib/api";
import { formatNumber, formatTugrik, relativeTime } from "@/lib/utils";

export default function CampaignsPage() {
  const router = useRouter();
  const [list, setList] = useState<Campaign[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    companyApi
      .list()
      .then(setList)
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
        title="Судалгаа"
        description="Таны бүх судалгааны бүртгэл"
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

      {list === null && !error && (
        <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
          Ачаалж байна...
        </div>
      )}

      {list && list.length === 0 && (
        <Card>
          <CardBody className="py-16 text-center text-sm text-[var(--color-text-muted)]">
            Кампани байхгүй байна. Дээрх товч дээр дараад эхлүүлээрэй.
          </CardBody>
        </Card>
      )}

      {list && list.length > 0 && (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
          {list.map((c) => {
            const spent = c.totalBudget - c.remainingBudget;
            const spendPct =
              c.totalBudget > 0 ? Math.round((spent / c.totalBudget) * 100) : 0;
            const awaitingPayment = c.status === "AWAITING_PAYMENT";

            return (
              <Link key={c.id} href={`/campaigns/${c.id}`} className="group">
                <Card className="h-full overflow-hidden transition-colors hover:border-[var(--color-text-muted)]">
                  <div className="relative flex aspect-video items-center justify-center bg-gradient-to-br from-[#2c2c38] to-[#17171e]">
                    {c.hasVideo ? (
                      <Play
                        size={48}
                        className="text-white/70"
                        fill="currentColor"
                      />
                    ) : (
                      <ClipboardList size={48} className="text-white/70" />
                    )}
                    <div className="absolute left-3 top-3">
                      <CampaignStatusBadge status={c.status} />
                    </div>
                    <div className="absolute right-3 top-3 rounded-md bg-black/55 px-2 py-1 text-xs font-semibold">
                      {c.hasVideo ? `${c.durationSeconds}s` : "Судалгаа"}
                    </div>
                  </div>
                  <CardBody>
                    <div className="line-clamp-2 font-semibold text-[var(--color-text-primary)]">
                      {c.title}
                    </div>
                    <div className="mt-1 text-xs text-[var(--color-text-muted)]">
                      Үүсгэсэн: {relativeTime(c.createdAt)}
                    </div>

                    <div className="mt-4 grid grid-cols-2 gap-3 text-xs">
                      <Stat
                        label="Хүрэх үзэгч"
                        value={
                          c.targetViewers === null
                            ? "—"
                            : formatNumber(c.targetViewers)
                        }
                      />
                      <Stat
                        label="Урамшуулал / үзэгч"
                        value={formatTugrik(c.rewardPerUser)}
                      />
                      <Stat
                        label="Зорилтот"
                        value={`${c.minAge}-${c.maxAge} нас`}
                      />
                      <Stat
                        label="Хот"
                        value={c.targetCity === "ALL" ? "Бүх" : c.targetCity}
                      />
                    </div>

                    {awaitingPayment ? (
                      // The whole card links to the detail page, which hosts
                      // the payment card — so this is styled as the CTA.
                      <div className="mt-4 flex items-center justify-between gap-3 rounded-xl border border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)] px-3 py-2">
                        <div className="text-xs text-[var(--color-text-secondary)]">
                          Төлөх дүн
                          <div className="font-mono text-sm font-bold text-[var(--color-text-primary)]">
                            {formatTugrik(c.totalBudget)}
                          </div>
                        </div>
                        <span className="inline-flex h-8 items-center gap-1.5 rounded-lg bg-[var(--color-primary)] px-3 text-xs font-semibold text-black group-hover:bg-[var(--color-primary-dark)]">
                          <CreditCard size={14} /> Төлөх
                        </span>
                      </div>
                    ) : (
                      <div className="mt-4">
                        <div className="mb-1 flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
                          <span>Төсөв</span>
                          <span className="font-mono text-[var(--color-text-primary)]">
                            {formatTugrik(spent)} /{" "}
                            {formatTugrik(c.totalBudget)}
                          </span>
                        </div>
                        <div className="h-1.5 overflow-hidden rounded-full bg-[var(--color-divider)]">
                          <div
                            className="h-full bg-[var(--color-primary)]"
                            style={{ width: `${spendPct}%` }}
                          />
                        </div>
                      </div>
                    )}
                  </CardBody>
                </Card>
              </Link>
            );
          })}
        </div>
      )}
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-text-muted)]">
        {label}
      </div>
      <div className="mt-0.5 font-mono font-semibold text-[var(--color-text-primary)]">
        {value}
      </div>
    </div>
  );
}
