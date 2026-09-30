"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  ArrowLeft,
  Building2,
  Check,
  ClipboardList,
  Eye,
  Play,
  X,
} from "lucide-react";
import { CampaignStatusBadge } from "@/components/campaign-status-badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import {
  adminApi,
  ApiError,
  auth,
  type AdminCampaignDetail,
} from "@/lib/api";
import { campaignInvoice } from "@/lib/billing";
import {
  formatDate,
  formatNumber,
  formatTugrik,
  relativeTime,
} from "@/lib/utils";

export default function AdminCampaignDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [data, setData] = useState<AdminCampaignDetail | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const reload = () => {
    if (!Number.isFinite(id)) return; // shown as `invalidId` below
    adminApi
      .campaign(id)
      .then(setData)
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
  };

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, router]);

  const moderate = async (decision: "ACTIVE" | "REJECTED") => {
    setBusy(true);
    try {
      await adminApi.moderate(id, decision);
      reload();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Алдаа");
    } finally {
      setBusy(false);
    }
  };

  const invalidId = !Number.isFinite(id);
  const shownError = invalidId ? "Кампанийн ID буруу" : error;

  if (shownError) {
    return (
      <>
        <BackLink />
        <Card>
          <CardBody className="py-10 text-center text-sm text-[var(--color-danger)]">
            {shownError}
          </CardBody>
        </Card>
      </>
    );
  }

  if (!data) {
    return (
      <>
        <BackLink />
        <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
          Ачаалж байна...
        </div>
      </>
    );
  }

  const { campaign: c, companyId, companyName, completedViews, spentBudget } =
    data;
  const unitLabel = c.hasVideo ? "үзэгч" : "хариулт";
  const invoice = campaignInvoice(c);

  return (
    <>
      <BackLink />

      <PageHeader
        title={c.title}
        description={
          c.hasVideo
            ? `${c.durationSeconds} сек · ${c.targetCity === "ALL" ? "Бүх хот" : c.targetCity}`
            : `Судалгаа зөвхөн · ${c.targetCity === "ALL" ? "Бүх хот" : c.targetCity}`
        }
        actions={
          <div className="flex items-center gap-2">
            <CampaignStatusBadge status={c.status} />
            {c.status === "PENDING" && (
              <>
                <Button
                  variant="secondary"
                  leftIcon={<X size={14} />}
                  onClick={() => moderate("REJECTED")}
                  disabled={busy}
                >
                  Татгалзах
                </Button>
                <Button
                  variant="success"
                  leftIcon={<Check size={14} />}
                  onClick={() => moderate("ACTIVE")}
                  disabled={busy}
                >
                  Баталгаажуулах
                </Button>
              </>
            )}
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard
          label="Гүйцэтгэсэн"
          value={formatNumber(completedViews)}
          icon={<Eye size={16} />}
          hint={`Нийт ${unitLabel}`}
        />
        <StatCard
          label="Зарцуулсан"
          value={formatTugrik(spentBudget)}
          hint={`/ ${formatTugrik(c.totalBudget)}`}
        />
        <StatCard
          label="Үлдэгдэл"
          value={formatTugrik(c.remainingBudget)}
        />
        <StatCard
          label="Урамшуулал"
          value={formatTugrik(c.rewardPerUser)}
          hint={`Нэг ${unitLabel}`}
        />
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Кампанийн мэдээлэл"
            description="Компанийн үүсгэсэн үед бөглөсөн тохиргоо"
          />
          <CardBody className="space-y-3 text-sm">
            <KV
              k="Төрөл"
              v={
                c.hasVideo ? (
                  <span className="flex items-center gap-1 justify-end">
                    <Play size={12} /> Видеотой
                  </span>
                ) : (
                  <span className="flex items-center gap-1 justify-end">
                    <ClipboardList size={12} /> Судалгаа зөвхөн
                  </span>
                )
              }
            />
            <KV k="Урт" v={c.hasVideo ? `${c.durationSeconds} сек` : "—"} />
            <KV k="Нийт төсөв" v={formatTugrik(c.totalBudget)} />
            <KV k="Хүрэх үзэгч" v={formatNumber(invoice.targetViewers)} />
            <KV k={`Үнэ / ${unitLabel}`} v={formatTugrik(c.costPerView)} />
            <KV
              k="Платформын шимтгэл"
              v={
                c.commissionPercent === null
                  ? formatTugrik(invoice.commissionTotal)
                  : `${c.commissionPercent}% · ${formatTugrik(invoice.commissionTotal)}`
              }
            />
            <KV
              k="Төлсөн огноо"
              v={
                c.paidAt
                  ? formatDate(c.paidAt)
                  : c.status === "AWAITING_PAYMENT"
                    ? "Төлөгдөөгүй"
                    : "—"
              }
            />
            <KV k="Үүсгэсэн" v={relativeTime(c.createdAt)} />
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Зорилтот" />
          <CardBody className="space-y-3 text-sm">
            <KV
              k="Хүйс"
              v={
                c.targetGender === "ALL"
                  ? "Бүгд"
                  : c.targetGender === "MALE"
                    ? "Эрэгтэй"
                    : "Эмэгтэй"
              }
            />
            <KV k="Нас" v={`${c.minAge} – ${c.maxAge}`} />
            <KV
              k="Хот"
              v={c.targetCity === "ALL" ? "Бүх" : c.targetCity}
            />
            <div className="border-t border-[var(--color-divider)] pt-3">
              <div className="mb-1 text-xs text-[var(--color-text-secondary)]">
                Эзэмшигч
              </div>
              {companyName ? (
                <Link
                  href={`/admin/companies/${companyId}`}
                  className="inline-flex items-center gap-2 rounded-lg px-2 py-1 -mx-2 hover:bg-[var(--color-surface-elevated)]"
                >
                  <Building2
                    size={14}
                    className="text-[var(--color-primary)]"
                  />
                  <span className="font-semibold text-[var(--color-text-primary)]">
                    {companyName}
                  </span>
                  <span className="text-xs text-[var(--color-text-muted)]">
                    (детайл харах)
                  </span>
                </Link>
              ) : (
                <span className="text-[var(--color-text-muted)]">
                  Компани олдсонгүй
                </span>
              )}
            </div>
          </CardBody>
        </Card>
      </div>
    </>
  );
}

function BackLink() {
  return (
    <Link
      href="/admin/campaigns"
      className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
    >
      <ArrowLeft size={12} /> Бүх кампани
    </Link>
  );
}

function KV({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between border-b border-[var(--color-divider)] pb-2 last:border-0 last:pb-0">
      <span className="text-[var(--color-text-secondary)]">{k}</span>
      <span className="font-mono text-[var(--color-text-primary)]">{v}</span>
    </div>
  );
}
