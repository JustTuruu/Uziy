import Link from "next/link";
import { Play, Plus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { mockCampaigns } from "@/lib/mock-data";
import { formatNumber, formatTugrik, relativeTime } from "@/lib/utils";

const statusTone = {
  ACTIVE: "success",
  PAUSED: "warning",
  PENDING: "info",
  COMPLETED: "neutral",
} as const;

const statusLabel = {
  ACTIVE: "Идэвхтэй",
  PAUSED: "Түр зогсоосон",
  PENDING: "Хүлээгдэж буй",
  COMPLETED: "Дууссан",
} as const;

export default function CampaignsPage() {
  const list = mockCampaigns.filter((c) => c.companyId === 100);

  return (
    <>
      <PageHeader
        title="Кампаниуд"
        description="Таны бүх видео сурталчилгааны бүртгэл"
        actions={
          <Link href="/company/campaigns/new">
            <Button leftIcon={<Plus size={16} />}>Шинэ кампани</Button>
          </Link>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
        {list.map((c) => {
          const rate =
            c.views === 0 ? 0 : Math.round((c.completions / c.views) * 100);
          const spent = c.totalBudget - c.remainingBudget;
          const spendPct = Math.round((spent / c.totalBudget) * 100);

          return (
            <Link
              key={c.id}
              href={`/company/campaigns/${c.id}`}
              className="group"
            >
              <Card className="h-full overflow-hidden transition-colors hover:border-[var(--color-text-muted)]">
                <div className="relative flex aspect-video items-center justify-center bg-gradient-to-br from-[#2c2c38] to-[#17171e]">
                  <Play
                    size={48}
                    className="text-white/70"
                    fill="currentColor"
                  />
                  <div className="absolute left-3 top-3">
                    <Badge tone={statusTone[c.status]}>
                      {statusLabel[c.status]}
                    </Badge>
                  </div>
                  <div className="absolute right-3 top-3 rounded-md bg-black/55 px-2 py-1 text-xs font-semibold">
                    {c.durationSeconds}s
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
                      label="Үзсэн"
                      value={formatNumber(c.views)}
                    />
                    <Stat label="Гүйцэтгэл" value={`${rate}%`} />
                    <Stat
                      label="Урамшуулал"
                      value={formatTugrik(c.rewardPerUser)}
                    />
                    <Stat
                      label="Зорилтот"
                      value={`${c.minAge}-${c.maxAge} нас`}
                    />
                  </div>

                  <div className="mt-4">
                    <div className="mb-1 flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
                      <span>Төсөв</span>
                      <span className="font-mono text-[var(--color-text-primary)]">
                        {formatTugrik(spent)} / {formatTugrik(c.totalBudget)}
                      </span>
                    </div>
                    <div className="h-1.5 overflow-hidden rounded-full bg-[var(--color-divider)]">
                      <div
                        className="h-full bg-[var(--color-primary)]"
                        style={{ width: `${spendPct}%` }}
                      />
                    </div>
                  </div>
                </CardBody>
              </Card>
            </Link>
          );
        })}
      </div>
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
