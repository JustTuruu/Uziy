"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CalendarCheck, CreditCard, Hourglass, Receipt } from "lucide-react";
import { Badge, Card, CardBody, CardHeader, PageHeader, StatCard } from "@uziy/ui";
import {
  ApiError,
  auth,
  companyApi,
  type Campaign,
  type Payment,
} from "@/lib/api";
import {
  PAYMENT_STATUS_LABEL,
  PAYMENT_STATUS_TONE,
  summarizeCampaignBudgets,
  summarizePayments,
} from "@/lib/billing";
import { formatDate, formatTugrik } from "@/lib/utils";

/**
 * Company billing: one payment per campaign, no account balance / top-up.
 * Shows what has been paid, which campaigns still await payment, and the
 * full payment history from GET /company/payments.
 */
export default function BillingPage() {
  const router = useRouter();
  const [payments, setPayments] = useState<Payment[] | null>(null);
  const [campaigns, setCampaigns] = useState<Campaign[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    Promise.all([companyApi.payments(), companyApi.list()])
      .then(([p, c]) => {
        setPayments(p);
        setCampaigns(c);
      })
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  const loading = (payments === null || campaigns === null) && !error;
  const { totalPaid, lastPaidAt } = summarizePayments(payments ?? []);
  const { awaitingPayment, awaitingPaymentTotal } = summarizeCampaignBudgets(
    campaigns ?? [],
  );

  return (
    <>
      <PageHeader
        title="Төлбөр"
        description="Аян тус бүрийн төлбөрөө энд хянана"
      />

      {error && (
        <div
          role="alert"
          className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]"
        >
          Төлбөрийн мэдээлэл ачаалахад алдаа гарлаа: {error}
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
        <StatCard
          label="Нийт төлсөн"
          value={loading || error ? "—" : formatTugrik(totalPaid)}
          icon={<CreditCard size={16} />}
        />
        <StatCard
          label="Төлбөр хүлээгдэж буй аян"
          value={loading || error ? "—" : String(awaitingPayment.length)}
          icon={<Hourglass size={16} />}
          hint={
            awaitingPayment.length > 0 ? (
              <Link
                href={
                  awaitingPayment.length === 1
                    ? `/campaigns/${awaitingPayment[0].id}`
                    : "#awaiting-payment"
                }
                className="font-semibold text-[var(--color-primary)] hover:underline"
              >
                {formatTugrik(awaitingPaymentTotal)} төлөх →
              </Link>
            ) : undefined
          }
        />
        <StatCard
          label="Сүүлийн төлбөр"
          value={
            loading || error ? "—" : lastPaidAt ? formatDate(lastPaidAt) : "—"
          }
          icon={<CalendarCheck size={16} />}
        />
      </div>

      {awaitingPayment.length > 0 && (
        <div id="awaiting-payment" className="mt-8">
          <Card>
            <CardHeader
              title="Төлбөр хүлээгдэж буй аян"
              description="Төлбөр төлөгдсөний дараа админ шалгаж баталгаажуулна"
            />
            <CardBody className="p-0">
              <table className="w-full text-sm">
                <tbody>
                  {awaitingPayment.map((c) => (
                    <tr
                      key={c.id}
                      className="border-b border-[var(--color-divider)] last:border-0"
                    >
                      <td className="px-5 py-3 text-[var(--color-text-primary)]">
                        {c.title}
                      </td>
                      <td className="px-5 py-3 text-right font-mono text-[var(--color-text-primary)]">
                        {formatTugrik(c.totalBudget)}
                      </td>
                      <td className="px-5 py-3 text-right">
                        <Link
                          href={`/campaigns/${c.id}`}
                          className="inline-flex h-8 items-center gap-1.5 rounded-lg bg-[var(--color-primary)] px-3 text-xs font-semibold text-black hover:bg-[var(--color-primary-dark)]"
                        >
                          <CreditCard size={14} /> Төлөх
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </CardBody>
          </Card>
        </div>
      )}

      <div className="mt-8">
        <Card>
          <CardHeader
            title="Төлбөрийн түүх"
            description="Шинэ нь эхэнд"
          />
          <CardBody className="p-0">
            {loading && (
              <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            )}
            {!loading && !error && payments && payments.length === 0 && (
              <div className="py-16 text-center text-sm text-[var(--color-text-muted)]">
                <Receipt size={20} className="mx-auto mb-2" />
                Одоогоор төлбөр хийгдээгүй байна.
              </div>
            )}
            {!loading && payments && payments.length > 0 && (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                    <th className="px-5 py-3 font-semibold">Дугаар</th>
                    <th className="px-5 py-3 font-semibold">Аян</th>
                    <th className="px-5 py-3 font-semibold">Огноо</th>
                    <th className="px-5 py-3 font-semibold text-right">Дүн</th>
                    <th className="px-5 py-3 font-semibold text-right">Төлөв</th>
                  </tr>
                </thead>
                <tbody>
                  {payments.map((p) => (
                    <tr
                      key={p.id}
                      className="border-b border-[var(--color-divider)] last:border-0"
                    >
                      <td className="px-5 py-3 font-mono text-[var(--color-text-primary)]">
                        {p.reference}
                      </td>
                      <td className="px-5 py-3">
                        <Link
                          href={`/campaigns/${p.campaignId}`}
                          className="text-[var(--color-text-primary)] hover:text-[var(--color-primary)] hover:underline"
                        >
                          {p.campaignTitle}
                        </Link>
                      </td>
                      <td className="px-5 py-3 text-[var(--color-text-secondary)]">
                        {formatDate(p.paidAt ?? p.createdAt)}
                      </td>
                      <td className="px-5 py-3 text-right font-mono text-[var(--color-text-primary)]">
                        {formatTugrik(p.amount)}
                      </td>
                      <td className="px-5 py-3 text-right">
                        <Badge tone={PAYMENT_STATUS_TONE[p.status] ?? "neutral"}>
                          {PAYMENT_STATUS_LABEL[p.status] ?? p.status}
                        </Badge>
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
