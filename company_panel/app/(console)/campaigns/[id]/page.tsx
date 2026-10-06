"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ArrowLeft,
  CircleCheck,
  ClipboardList,
  Hourglass,
  Pause,
  Play,
} from "lucide-react";
import { CampaignPaymentCard } from "@/components/campaign-payment-card";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Button, Card, CardBody, CardHeader, PageHeader, StatCard } from "@uziy/ui";
import { ApiError, auth, companyApi, type Campaign } from "@/lib/api";
import { campaignInvoice } from "@/lib/billing";
import {
  companyStatusTransitions,
  type CompanySettableStatus,
} from "@/lib/campaign-status";
import { formatDate, formatNumber, formatTugrik } from "@/lib/utils";

export default function CampaignDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  // Keeps the payment card (in its success state) on screen after paying,
  // even though the campaign itself has moved on to PENDING.
  const [justPaid, setJustPaid] = useState(false);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    if (!Number.isFinite(id)) return; // shown as `invalidId` below
    companyApi
      .get(id)
      .then(setCampaign)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        if (e instanceof ApiError && e.status === 404) {
          setError("Кампани олдсонгүй");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [id, router]);

  const setStatus = async (next: CompanySettableStatus) => {
    if (!campaign) return;
    if (
      next === "COMPLETED" &&
      !window.confirm(
        "Аяныг дуусгах уу? Дууссан аяныг дахин идэвхжүүлэх боломжгүй.",
      )
    ) {
      return;
    }
    setBusy(true);
    setActionError(null);
    try {
      const updated = await companyApi.setStatus(campaign.id, next);
      setCampaign(updated);
    } catch (e) {
      // Keep the page; a failed action (e.g. 409 on a stale status) should
      // not replace the whole campaign view with an error.
      setActionError(e instanceof ApiError ? e.message : "Алдаа гарлаа");
    } finally {
      setBusy(false);
    }
  };

  const invalidId = !Number.isFinite(id);
  const shownError = invalidId ? "Кампанийн ID буруу" : error;

  if (shownError) {
    return (
      <>
        <Link
          href="/campaigns"
          className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
        >
          <ArrowLeft size={12} /> Бүх кампани
        </Link>
        <Card>
          <CardBody className="py-10 text-center text-sm text-[var(--color-danger)]">
            {shownError}
          </CardBody>
        </Card>
      </>
    );
  }

  if (!campaign) {
    return (
      <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
        Ачаалж байна...
      </div>
    );
  }

  const spent = campaign.totalBudget - campaign.remainingBudget;
  const invoice = campaignInvoice(campaign);
  const transitions = companyStatusTransitions(campaign.status);
  const showPayment = campaign.status === "AWAITING_PAYMENT" || justPaid;

  return (
    <>
      <Link
        href="/campaigns"
        className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
      >
        <ArrowLeft size={12} /> Буцах
      </Link>

      <PageHeader
        title={campaign.title}
        description={
          campaign.hasVideo
            ? `${campaign.durationSeconds} сек · ${campaign.targetCity === "ALL" ? "Бүх хот" : campaign.targetCity}`
            : `Судалгаа зөвхөн · ${campaign.targetCity === "ALL" ? "Бүх хот" : campaign.targetCity}`
        }
        actions={
          <div className="flex items-center gap-2">
            <CampaignStatusBadge status={campaign.status} />
            {transitions.includes("PAUSED") && (
              <Button
                variant="secondary"
                leftIcon={<Pause size={14} />}
                onClick={() => setStatus("PAUSED")}
                disabled={busy}
              >
                Түр зогсоох
              </Button>
            )}
            {transitions.includes("ACTIVE") && (
              <Button
                leftIcon={<Play size={14} />}
                onClick={() => setStatus("ACTIVE")}
                disabled={busy}
              >
                Үргэлжлүүлэх
              </Button>
            )}
            {transitions.includes("COMPLETED") && (
              <Button
                variant="ghost"
                leftIcon={<CircleCheck size={14} />}
                onClick={() => setStatus("COMPLETED")}
                disabled={busy}
              >
                Дуусгах
              </Button>
            )}
          </div>
        }
      />

      {actionError && (
        <div
          role="alert"
          className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]"
        >
          {actionError}
        </div>
      )}

      {showPayment && (
        <div className="mb-8 max-w-xl">
          <CampaignPaymentCard
            campaign={campaign}
            onPaid={({ campaign: updated }) => {
              setJustPaid(true);
              setCampaign(updated);
            }}
          />
        </div>
      )}

      {campaign.status === "PENDING" && !justPaid && (
        <div className="mb-6 flex items-center gap-2 rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-text-primary)]">
          <Hourglass
            size={14}
            className="shrink-0 text-[var(--color-accent)]"
          />
          Төлбөр төлөгдсөн. Админ шалгаж баталгаажуулсны дараа аян идэвхжинэ.
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard
          label="Зарцуулсан"
          value={formatTugrik(spent)}
          hint={`/ ${formatTugrik(campaign.totalBudget)}`}
        />
        <StatCard
          label="Үлдэгдэл"
          value={formatTugrik(campaign.remainingBudget)}
        />
        <StatCard
          label="Хүрэх үзэгч"
          value={formatNumber(invoice.targetViewers)}
        />
        <StatCard
          label="Урамшуулал / үзэгч"
          value={formatTugrik(campaign.rewardPerUser)}
        />
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Судалгааны хариултууд"
            description="Backend-д агрегатор нэмэгдэх хүртэл харагдахгүй"
          />
          <CardBody className="py-10 text-center text-sm text-[var(--color-text-muted)]">
            {campaign.hasVideo ? (
              <div className="flex items-center justify-center gap-2">
                <Play size={16} /> Судалгааны agregate endpoint удахгүй.
              </div>
            ) : (
              <div className="flex items-center justify-center gap-2">
                <ClipboardList size={16} /> Судалгааны agregate endpoint
                удахгүй.
              </div>
            )}
          </CardBody>
        </Card>

        <div className="space-y-4">
          <Card>
            <CardHeader title="Зорилтот" />
            <CardBody className="space-y-3 text-sm">
              <KV
                k="Хүйс"
                v={
                  campaign.targetGender === "ALL"
                    ? "Бүгд"
                    : campaign.targetGender === "MALE"
                      ? "Эрэгтэй"
                      : "Эмэгтэй"
                }
              />
              <KV k="Нас" v={`${campaign.minAge} – ${campaign.maxAge}`} />
              <KV
                k="Хот"
                v={campaign.targetCity === "ALL" ? "Бүх" : campaign.targetCity}
              />
              <KV
                k="Төрөл"
                v={campaign.hasVideo ? "Видеотой" : "Судалгаа зөвхөн"}
              />
            </CardBody>
          </Card>

          <Card>
            <CardHeader title="Төлбөр" />
            <CardBody className="space-y-3 text-sm">
              <KV k="Нийт төсөв" v={formatTugrik(invoice.payable)} />
              <KV k="Үзэгчдэд олгох" v={formatTugrik(invoice.rewardsTotal)} />
              <KV
                k={
                  invoice.commissionPercent === null
                    ? "Платформын шимтгэл"
                    : `Платформын шимтгэл (${invoice.commissionPercent}%)`
                }
                v={formatTugrik(invoice.commissionTotal)}
              />
              <KV
                k="Төлсөн огноо"
                v={
                  campaign.paidAt
                    ? formatDate(campaign.paidAt)
                    : campaign.status === "AWAITING_PAYMENT"
                      ? "Төлөгдөөгүй"
                      : "—"
                }
              />
            </CardBody>
          </Card>
        </div>
      </div>
    </>
  );
}

function KV({ k, v }: { k: string; v: string }) {
  return (
    <div className="flex items-center justify-between border-b border-[var(--color-divider)] pb-2 last:border-0 last:pb-0">
      <span className="text-[var(--color-text-secondary)]">{k}</span>
      <span className="font-mono text-[var(--color-text-primary)]">{v}</span>
    </div>
  );
}
