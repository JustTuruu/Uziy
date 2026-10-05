"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import {
  CircleAlert,
  CircleCheck,
  CreditCard,
  FlaskConical,
  LoaderCircle,
  RotateCcw,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import {
  ApiError,
  auth,
  companyApi,
  type Campaign,
  type PayCampaignResponse,
  type Payment,
} from "@/lib/api";
import { campaignInvoice } from "@/lib/billing";
import { formatNumber, formatTugrik } from "@/lib/utils";

type Phase = "idle" | "paying" | "paid" | "error";

export function CampaignPaymentCard({
  campaign,
  variant = "detail",
  onPaid,
}: {
  campaign: Campaign;
  variant?: "wizard" | "detail";
  onPaid?: (result: PayCampaignResponse) => void;
}) {
  const router = useRouter();
  const [phase, setPhase] = useState<Phase>("idle");
  const [error, setError] = useState<string | null>(null);
  const [payment, setPayment] = useState<Payment | null>(null);

  const invoice = campaignInvoice(campaign);

  const pay = async () => {
    if (phase === "paying") return;
    setPhase("paying");
    setError(null);
    try {
      const res = await companyApi.pay(campaign.id);
      setPayment(res.payment);
      setPhase("paid");
      onPaid?.(res);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        auth.clear();
        router.replace("/login");
        return;
      }
      setError(
        e instanceof ApiError ? e.message : "Төлбөр төлөхөд алдаа гарлаа",
      );
      setPhase("error");
    }
  };

  if (phase === "paid") {
    return (
      <Card>
        <CardBody className="flex flex-col items-center gap-3 py-10 text-center">
          <CircleCheck size={40} className="text-[var(--color-success)]" />
          <div className="text-lg font-extrabold text-[var(--color-text-primary)]">
            Төлбөр амжилттай төлөгдлөө
          </div>
          <div className="max-w-md text-sm text-[var(--color-text-secondary)]">
            Админ шалгаж баталгаажуулсны дараа аян идэвхжинэ.
          </div>
          {payment && (
            <div className="font-mono text-xs text-[var(--color-text-muted)]">
              {payment.reference} · {formatTugrik(payment.amount)}
            </div>
          )}
          {variant === "wizard" && (
            <div className="mt-2 flex flex-wrap justify-center gap-2">
              <Link href={`/company/campaigns/${campaign.id}`}>
                <Button>Аян руу очих</Button>
              </Link>
              <Link href="/company/campaigns">
                <Button variant="secondary">Бүх аян</Button>
              </Link>
            </div>
          )}
        </CardBody>
      </Card>
    );
  }

  const paying = phase === "paying";

  return (
    <Card>
      <CardHeader
        title="Төлбөр"
        description="Аян тус бүрийн төлбөрийг тусад нь төлнө — данс цэнэглэх шаардлагагүй"
      />
      <CardBody className="space-y-5">
        <div>
          <div className="text-xs text-[var(--color-text-secondary)]">Аян</div>
          <div className="mt-0.5 font-semibold text-[var(--color-text-primary)]">
            {campaign.title}
          </div>
        </div>

        <div className="rounded-xl border border-[color-mix(in_oklab,var(--color-primary)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-primary)_8%,transparent)] p-4">
          <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
            Төлөх дүн
          </div>
          <div className="mt-1 font-mono text-3xl font-extrabold text-[var(--color-primary)]">
            {formatTugrik(invoice.payable)}
          </div>
        </div>

        <div className="space-y-3 text-sm">
          <Row
            label="Үзэгчдэд олгох нийт урамшуулал"
            sub={`${formatNumber(invoice.targetViewers)} үзэгч × ${formatTugrik(invoice.rewardPerViewer)}`}
            value={formatTugrik(invoice.rewardsTotal)}
          />
          <Row
            label={
              invoice.commissionPercent === null
                ? "Платформын шимтгэл"
                : `Платформын шимтгэл (${invoice.commissionPercent}%)`
            }
            value={formatTugrik(invoice.commissionTotal)}
          />
        </div>

        <div className="flex items-start gap-2 rounded-lg border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-text-primary)]">
          <FlaskConical
            size={14}
            className="mt-0.5 shrink-0 text-[var(--color-accent)]"
          />
          <span>Туршилтын горим: одоогоор бодит төлбөр хийгдэхгүй</span>
        </div>

        {phase === "error" && error && (
          <div
            role="alert"
            className="space-y-1 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]"
          >
            <div className="flex items-start gap-2">
              <CircleAlert size={14} className="mt-0.5 shrink-0" />
              <span>{error}</span>
            </div>
            {variant === "wizard" && (
              <div className="pl-6 text-[var(--color-text-secondary)]">
                Аян хадгалагдсан тул дараа нь{" "}
                <Link
                  href={`/company/campaigns/${campaign.id}`}
                  className="font-semibold text-[var(--color-text-primary)] underline"
                >
                  аяны хуудаснаас
                </Link>{" "}
                төлж болно.
              </div>
            )}
          </div>
        )}

        <Button
          size="lg"
          className="w-full"
          onClick={pay}
          disabled={paying}
          leftIcon={
            paying ? (
              <LoaderCircle size={16} className="animate-spin" />
            ) : phase === "error" ? (
              <RotateCcw size={16} />
            ) : (
              <CreditCard size={16} />
            )
          }
        >
          {paying
            ? "Төлж байна..."
            : phase === "error"
              ? "Дахин оролдох"
              : "Төлөх"}
        </Button>
      </CardBody>
    </Card>
  );
}

function Row({
  label,
  sub,
  value,
}: {
  label: string;
  sub?: string;
  value: string;
}) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-[var(--color-divider)] pb-3 last:border-0 last:pb-0">
      <div>
        <div className="text-[var(--color-text-secondary)]">{label}</div>
        {sub && (
          <div className="mt-0.5 text-xs text-[var(--color-text-muted)]">
            {sub}
          </div>
        )}
      </div>
      <div className="font-mono text-[var(--color-text-primary)]">{value}</div>
    </div>
  );
}
