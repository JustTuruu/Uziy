import { CreditCard, Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import { companyStats } from "@/lib/mock-data";
import { formatTugrik } from "@/lib/utils";

const invoices = [
  { id: "INV-2026-0091", date: "2026-09-01", amount: 2_000_000, status: "PAID" },
  { id: "INV-2026-0082", date: "2026-08-01", amount: 1_500_000, status: "PAID" },
  { id: "INV-2026-0073", date: "2026-07-01", amount: 800_000, status: "PAID" },
];

export default function BillingPage() {
  return (
    <>
      <PageHeader
        title="Төлбөр"
        description="Дансаа цэнэглэж, нэхэмжлэлүүдээ хянана уу"
        actions={
          <Button leftIcon={<Plus size={16} />}>Данс цэнэглэх</Button>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <StatCard
          label="Дансны үлдэгдэл"
          value={formatTugrik(companyStats.accountBalance)}
          icon={<CreditCard size={16} />}
        />
        <StatCard
          label="Энэ сарын зарцуулалт"
          value={formatTugrik(companyStats.totalSpent)}
        />
        <StatCard
          label="Дундаж CPV"
          value={formatTugrik(920)}
          hint="Зорилтот нарийвчлалаар өөр өөр"
        />
      </div>

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Нэхэмжлэлүүд"
            description="Сүүлийн 3 сарын түүх"
          />
          <CardBody className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Дугаар</th>
                  <th className="px-5 py-3 font-semibold">Огноо</th>
                  <th className="px-5 py-3 font-semibold text-right">Дүн</th>
                  <th className="px-5 py-3 font-semibold text-right">Төлөв</th>
                </tr>
              </thead>
              <tbody>
                {invoices.map((inv) => (
                  <tr
                    key={inv.id}
                    className="border-b border-[var(--color-divider)] last:border-0"
                  >
                    <td className="px-5 py-3 font-mono text-[var(--color-text-primary)]">
                      {inv.id}
                    </td>
                    <td className="px-5 py-3 text-[var(--color-text-secondary)]">
                      {inv.date}
                    </td>
                    <td className="px-5 py-3 text-right font-mono text-[var(--color-text-primary)]">
                      {formatTugrik(inv.amount)}
                    </td>
                    <td className="px-5 py-3 text-right">
                      <span className="inline-block rounded-full bg-[color-mix(in_oklab,var(--color-success)_15%,transparent)] px-2 py-0.5 text-xs font-semibold text-[var(--color-success)]">
                        {inv.status}
                      </span>
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
