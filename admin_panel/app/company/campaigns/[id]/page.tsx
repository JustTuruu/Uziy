"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { ArrowLeft, ClipboardList, Pause, Play } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import {
  ApiError,
  auth,
  companyApi,
  type Campaign,
} from "@/lib/api";
import { formatTugrik } from "@/lib/utils";

const statusTone = {
  ACTIVE: "success",
  PAUSED: "warning",
  PENDING: "info",
  COMPLETED: "neutral",
  REJECTED: "danger",
} as const;

const statusLabel = {
  ACTIVE: "Идэвхтэй",
  PAUSED: "Түр зогсоосон",
  PENDING: "Хүлээгдэж буй",
  COMPLETED: "Дууссан",
  REJECTED: "Татгалзсан",
} as const;

export default function CampaignDetailPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const id = Number(params.id);

  const [campaign, setCampaign] = useState<Campaign | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    if (!Number.isFinite(id)) {
      setError("Кампанийн ID буруу");
      return;
    }
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

  const setStatus = async (next: "ACTIVE" | "PAUSED" | "COMPLETED") => {
    if (!campaign) return;
    setBusy(true);
    try {
      const updated = await companyApi.setStatus(campaign.id, next);
      setCampaign(updated);
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Алдаа гарлаа");
    } finally {
      setBusy(false);
    }
  };

  if (error) {
    return (
      <>
        <Link
          href="/company/campaigns"
          className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
        >
          <ArrowLeft size={12} /> Бүх кампани
        </Link>
        <Card>
          <CardBody className="py-10 text-center text-sm text-[var(--color-danger)]">
            {error}
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
  const unitLabel = campaign.hasVideo ? "үзэгч" : "хариулт";

  return (
    <>
      <Link
        href="/company/campaigns"
        className="mb-4 inline-flex items-center gap-1 text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
      >
        <ArrowLeft size={12} /> Бүх кампани
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
            <Badge tone={statusTone[campaign.status]}>
              {statusLabel[campaign.status]}
            </Badge>
            {campaign.status === "ACTIVE" && (
              <Button
                variant="secondary"
                leftIcon={<Pause size={14} />}
                onClick={() => setStatus("PAUSED")}
                disabled={busy}
              >
                Түр зогсоох
              </Button>
            )}
            {campaign.status === "PAUSED" && (
              <Button
                leftIcon={<Play size={14} />}
                onClick={() => setStatus("ACTIVE")}
                disabled={busy}
              >
                Үргэлжлүүлэх
              </Button>
            )}
          </div>
        }
      />

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
          label={`Үнэ / ${unitLabel}`}
          value={formatTugrik(campaign.costPerView)}
        />
        <StatCard
          label="Урамшуулал"
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
                <ClipboardList size={16} /> Судалгааны agregate endpoint удахгүй.
              </div>
            )}
          </CardBody>
        </Card>

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
            <KV k="Төрөл" v={campaign.hasVideo ? "Видеотой" : "Судалгаа зөвхөн"} />
          </CardBody>
        </Card>
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
