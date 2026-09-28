import Link from "next/link";
import {
  ArrowUpRight,
  Eye,
  Play,
  Plus,
  TrendingUp,
  Users,
  Wallet,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import { companyStats, mockCampaigns } from "@/lib/mock-data";
import { formatNumber, formatTugrik } from "@/lib/utils";

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

export default function CompanyDashboard() {
  // Show only campaigns "owned" by this fake company (companyId=100).
  const myCampaigns = mockCampaigns.filter((c) => c.companyId === 100);

  return (
    <>
      <PageHeader
        title="Сайн байна уу, MobiCom 👋"
        description="Энэ 7 хоногт таны кампаниуд хэрхэн ажилласан бэ?"
        actions={
          <Link href="/company/campaigns/new">
            <Button leftIcon={<Plus size={16} />}>Шинэ кампани</Button>
          </Link>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="Идэвхтэй кампани"
          value={companyStats.activeCampaigns}
          icon={<Play size={16} />}
        />
        <StatCard
          label="Нийт хүрсэн хүн"
          value={formatNumber(companyStats.totalReach)}
          icon={<Users size={16} />}
          trend={{ direction: "up", value: "+12%" }}
        />
        <StatCard
          label="Нийт зарцуулалт"
          value={formatTugrik(companyStats.totalSpent)}
          icon={<TrendingUp size={16} />}
          hint="Энэ сар"
        />
        <StatCard
          label="Дансны үлдэгдэл"
          value={formatTugrik(companyStats.accountBalance)}
          icon={<Wallet size={16} />}
          hint={
            <Link
              href="/company/billing"
              className="inline-flex items-center gap-1 text-[var(--color-primary)] hover:underline"
            >
              Цэнэглэх <ArrowUpRight size={12} />
            </Link>
          }
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Кампаниуд"
            description="Таны бүх идэвхтэй болон хүлээгдэж буй сурталчилгаанууд"
            action={
              <Link href="/company/campaigns">
                <Button variant="ghost" size="sm">
                  Бүгд харах
                </Button>
              </Link>
            }
          />
          <CardBody className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Гарчиг</th>
                  <th className="px-5 py-3 font-semibold">Төлөв</th>
                  <th className="px-5 py-3 font-semibold text-right">Үзсэн</th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Гүйцэтгэл
                  </th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Үлдэгдэл
                  </th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Урамшуулал / үзэгч
                  </th>
                </tr>
              </thead>
              <tbody>
                {myCampaigns.map((c) => {
                  const rate =
                    c.views === 0
                      ? 0
                      : Math.round((c.completions / c.views) * 100);
                  return (
                    <tr
                      key={c.id}
                      className="border-b border-[var(--color-divider)] last:border-0 hover:bg-[var(--color-surface-elevated)]/60"
                    >
                      <td className="px-5 py-4">
                        <Link
                          href={`/company/campaigns/${c.id}`}
                          className="flex items-center gap-3"
                        >
                          <div className="flex h-10 w-16 items-center justify-center rounded-md bg-gradient-to-br from-[#2c2c38] to-[#17171e]">
                            <Play
                              size={14}
                              className="text-white/70"
                              fill="currentColor"
                            />
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--color-text-primary)]">
                              {c.title}
                            </div>
                            <div className="text-xs text-[var(--color-text-muted)]">
                              {c.durationSeconds} сек · {c.targetCity}
                            </div>
                          </div>
                        </Link>
                      </td>
                      <td className="px-5 py-4">
                        <Badge tone={statusTone[c.status]}>
                          {statusLabel[c.status]}
                        </Badge>
                      </td>
                      <td className="px-5 py-4 text-right font-mono text-[var(--color-text-primary)]">
                        {formatNumber(c.views)}
                      </td>
                      <td className="px-5 py-4 text-right">
                        <span className="inline-flex items-center gap-2">
                          <span className="font-mono text-[var(--color-text-primary)]">
                            {rate}%
                          </span>
                          <span className="inline-block h-1.5 w-16 overflow-hidden rounded-full bg-[var(--color-divider)]">
                            <span
                              className="block h-full bg-[var(--color-primary)]"
                              style={{ width: `${rate}%` }}
                            />
                          </span>
                        </span>
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
                        <span className="inline-flex items-center gap-1">
                          <Eye
                            size={12}
                            className="text-[var(--color-text-muted)]"
                          />
                          {formatTugrik(c.rewardPerUser)}
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
