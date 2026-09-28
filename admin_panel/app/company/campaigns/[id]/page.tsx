import Link from "next/link";
import { notFound } from "next/navigation";
import { ArrowLeft, Pause, Play } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { StatCard } from "@/components/stat-card";
import { mockCampaigns, mockSurveyResponses } from "@/lib/mock-data";
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

export default async function CampaignDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const campaign = mockCampaigns.find((c) => c.id === Number(id));
  if (!campaign) notFound();

  const rate =
    campaign.views === 0
      ? 0
      : Math.round((campaign.completions / campaign.views) * 100);
  const responses = mockSurveyResponses.filter(
    (r) => r.campaignId === campaign.id,
  );

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
        description={`${campaign.durationSeconds} сек · ${campaign.targetCity}`}
        actions={
          <div className="flex items-center gap-2">
            <Badge tone={statusTone[campaign.status]}>
              {statusLabel[campaign.status]}
            </Badge>
            {campaign.status === "ACTIVE" ? (
              <Button variant="secondary" leftIcon={<Pause size={14} />}>
                Түр зогсоох
              </Button>
            ) : campaign.status === "PAUSED" ? (
              <Button leftIcon={<Play size={14} />}>Үргэлжлүүлэх</Button>
            ) : null}
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-4 md:grid-cols-4">
        <StatCard label="Үзсэн" value={formatNumber(campaign.views)} />
        <StatCard
          label="Гүйцэтгэсэн"
          value={formatNumber(campaign.completions)}
          hint={`${rate}% гүйцэтгэл`}
        />
        <StatCard
          label="Зарцуулсан"
          value={formatTugrik(campaign.totalBudget - campaign.remainingBudget)}
          hint={`/ ${formatTugrik(campaign.totalBudget)}`}
        />
        <StatCard
          label="Үлдэгдэл"
          value={formatTugrik(campaign.remainingBudget)}
        />
      </div>

      <div className="mt-8 grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Судалгааны хариултууд"
            description="Хэрэглэгчид энэ видеог үзсэний дараа юу гэж хариулав"
          />
          <CardBody className="space-y-6">
            {responses.length === 0 && (
              <div className="text-sm text-[var(--color-text-muted)]">
                Хариулт хараахан алга.
              </div>
            )}
            {responses.map((r) => {
              const total = r.breakdown.reduce((s, b) => s + b.count, 0);
              return (
                <div key={r.questionId}>
                  <div className="mb-3 text-sm font-semibold">
                    {r.prompt}
                  </div>
                  <div className="space-y-2">
                    {r.breakdown.map((b) => {
                      const pct = Math.round((b.count / total) * 100);
                      return (
                        <div key={b.label}>
                          <div className="mb-1 flex items-center justify-between text-xs">
                            <span className="text-[var(--color-text-secondary)]">
                              {b.label}
                            </span>
                            <span className="font-mono text-[var(--color-text-primary)]">
                              {formatNumber(b.count)} · {pct}%
                            </span>
                          </div>
                          <div className="h-1.5 overflow-hidden rounded-full bg-[var(--color-divider)]">
                            <div
                              className="h-full bg-[var(--color-primary)]"
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
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
            <KV k="Зардал / үзэгч" v={formatTugrik(campaign.costPerView)} />
            <KV
              k="Урамшуулал / үзэгч"
              v={formatTugrik(campaign.rewardPerUser)}
            />
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
