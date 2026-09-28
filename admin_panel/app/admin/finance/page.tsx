import { Banknote, PiggyBank, TrendingUp } from "lucide-react";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import { platformStats } from "@/lib/mock-data";
import { formatTugrik } from "@/lib/utils";

const monthlyLedger = [
  { month: "2026-09", gmv: 22_400_000, commission: 7_840_000, payouts: 12_600_000 },
  { month: "2026-08", gmv: 19_100_000, commission: 6_685_000, payouts: 10_800_000 },
  { month: "2026-07", gmv: 17_500_000, commission: 6_125_000, payouts: 9_900_000 },
  { month: "2026-06", gmv: 14_800_000, commission: 5_180_000, payouts: 8_400_000 },
  { month: "2026-05", gmv: 12_600_000, commission: 4_410_000, payouts: 7_200_000 },
];

export default function FinancePage() {
  const commissionAllTime = Math.round(
    platformStats.totalGmv * platformStats.commissionRate,
  );
  const payoutsAllTime = platformStats.totalGmv - commissionAllTime;

  return (
    <>
      <PageHeader
        title="Санхүү"
        description="Платформын нийт орлого болон хэрэглэгчид олгосон урамшуулал"
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <StatCard
          label="Нийт GMV"
          value={formatTugrik(platformStats.totalGmv)}
          icon={<TrendingUp size={16} />}
        />
        <StatCard
          label="Шимтгэлийн орлого"
          value={formatTugrik(commissionAllTime)}
          icon={<Banknote size={16} />}
          hint={`${Math.round(platformStats.commissionRate * 100)}% шимтгэл`}
        />
        <StatCard
          label="Хэрэглэгчид олгосон"
          value={formatTugrik(payoutsAllTime)}
          icon={<PiggyBank size={16} />}
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Сар бүрийн жагсаалт"
            description="Сүүлийн 5 сар"
          />
          <CardBody className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Сар</th>
                  <th className="px-5 py-3 font-semibold text-right">GMV</th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Шимтгэл
                  </th>
                  <th className="px-5 py-3 font-semibold text-right">
                    Хэрэглэгчид
                  </th>
                </tr>
              </thead>
              <tbody>
                {monthlyLedger.map((r) => (
                  <tr
                    key={r.month}
                    className="border-b border-[var(--color-divider)] last:border-0"
                  >
                    <td className="px-5 py-3 font-mono">{r.month}</td>
                    <td className="px-5 py-3 text-right font-mono">
                      {formatTugrik(r.gmv)}
                    </td>
                    <td className="px-5 py-3 text-right font-mono text-[var(--color-primary)]">
                      {formatTugrik(r.commission)}
                    </td>
                    <td className="px-5 py-3 text-right font-mono">
                      {formatTugrik(r.payouts)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
