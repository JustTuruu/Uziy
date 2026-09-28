"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import {
  Calculator,
  Check,
  ChevronLeft,
  ChevronRight,
  Plus,
  Trash2,
  Upload,
} from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input, Select, Textarea } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import { cn, formatNumber, formatTugrik } from "@/lib/utils";

type Step = "video" | "targeting" | "budget" | "survey" | "review";

const steps: { id: Step; label: string }[] = [
  { id: "video", label: "Видео" },
  { id: "targeting", label: "Зорилтот" },
  { id: "budget", label: "Төсөв" },
  { id: "survey", label: "Судалгаа" },
  { id: "review", label: "Хянах" },
];

const cities = [
  "ALL",
  "Улаанбаатар",
  "Дархан",
  "Эрдэнэт",
  "Чойбалсан",
  "Мөрөн",
  "Ховд",
  "Өлгий",
];

interface SurveyQ {
  id: number;
  prompt: string;
  type: "SINGLE_CHOICE" | "MULTI_CHOICE" | "TEXT";
  options: string[];
}

export default function NewCampaignPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>("video");

  // Step 1
  const [title, setTitle] = useState("");
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [duration, setDuration] = useState<number>(30);

  // Step 2
  const [gender, setGender] = useState<"ALL" | "MALE" | "FEMALE">("ALL");
  const [minAge, setMinAge] = useState(18);
  const [maxAge, setMaxAge] = useState(45);
  const [city, setCity] = useState<string>("Улаанбаатар");

  // Step 3
  const [totalBudget, setTotalBudget] = useState(1_000_000);
  const [rewardPerUser, setRewardPerUser] = useState(600);

  // Step 4
  const [questions, setQuestions] = useState<SurveyQ[]>([
    {
      id: 1,
      prompt: "Энэ реклам танд сонирхолтой санагдсан уу?",
      type: "SINGLE_CHOICE",
      options: ["Тийм", "Дунд зэрэг", "Үгүй"],
    },
  ]);

  // Derived pricing — the spec says cost_per_view grows with targeting precision.
  // Simple model: base 500₮/view, +100 per narrow filter, +200 for gender lock,
  // +150 if age window ≤ 10 years, +200 if city != ALL.
  const costPerView = useMemo(() => {
    let cost = 500;
    if (gender !== "ALL") cost += 200;
    if (maxAge - minAge <= 10) cost += 150;
    if (city !== "ALL") cost += 200;
    return cost;
  }, [gender, minAge, maxAge, city]);

  // Admin commission: 35%. Company must cover cost = reward + commission per view.
  const platformFeePerView = Math.max(0, costPerView - rewardPerUser);
  const projectedReach = Math.floor(totalBudget / costPerView);

  const stepIndex = steps.findIndex((s) => s.id === step);
  const canPrev = stepIndex > 0;
  const canNext = stepIndex < steps.length - 1;

  const submit = async () => {
    // TODO: POST /campaigns (multipart with video file) — backend transcodes
    // via the FFmpeg worker and uploads HLS to Cloudflare R2.
    await new Promise((r) => setTimeout(r, 400));
    router.push("/company/campaigns");
  };

  return (
    <>
      <PageHeader
        title="Шинэ кампани үүсгэх"
        description="Видео байршуулж, зорилтот үзэгчээ тодорхойлно уу"
      />

      <Stepper current={stepIndex} />

      <div className="mt-8">
        {step === "video" && (
          <Card>
            <CardHeader
              title="Видео байршуулах"
              description="MP4 форматтай, 30 сек – 2 минутын урттай байх"
            />
            <CardBody className="space-y-5">
              <Input
                label="Гарчиг"
                placeholder="Ж-нь: Шинэ 5G багц"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />

              <label className="block">
                <div className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Видео файл
                </div>
                <div
                  className={cn(
                    "flex flex-col items-center justify-center gap-2 rounded-2xl border-2 border-dashed p-8 text-center transition-colors",
                    videoFile
                      ? "border-[var(--color-primary)] bg-[color-mix(in_oklab,var(--color-primary)_5%,transparent)]"
                      : "border-[var(--color-divider)] hover:border-[var(--color-text-muted)]",
                  )}
                >
                  <Upload
                    size={26}
                    className="text-[var(--color-text-muted)]"
                  />
                  <div className="text-sm font-semibold">
                    {videoFile
                      ? videoFile.name
                      : "MP4 файл сонгох эсвэл чирж оруулах"}
                  </div>
                  <div className="text-xs text-[var(--color-text-muted)]">
                    Дээд хэмжээ 500MB
                  </div>
                  <input
                    type="file"
                    accept="video/mp4"
                    className="hidden"
                    id="video-input"
                    onChange={(e) =>
                      setVideoFile(e.target.files?.[0] ?? null)
                    }
                  />
                  <label htmlFor="video-input">
                    <span
                      className={cn(
                        "mt-2 inline-flex cursor-pointer items-center rounded-xl bg-[var(--color-surface-elevated)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-primary)]",
                      )}
                    >
                      Файл сонгох
                    </span>
                  </label>
                </div>
              </label>

              <Input
                label="Урт (секунд)"
                type="number"
                min={30}
                max={120}
                value={duration}
                onChange={(e) => setDuration(Number(e.target.value))}
                hint="30 – 120 сек"
              />
            </CardBody>
          </Card>
        )}

        {step === "targeting" && (
          <Card>
            <CardHeader
              title="Зорилтот үзэгч"
              description="Нарийвчлал өндөр байх тусам нэг үзэгчийн үнэ өснө"
            />
            <CardBody className="space-y-6">
              <div>
                <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                  Хүйс
                </div>
                <div className="grid grid-cols-3 gap-2">
                  {(["ALL", "MALE", "FEMALE"] as const).map((g) => (
                    <button
                      key={g}
                      type="button"
                      onClick={() => setGender(g)}
                      className={cn(
                        "rounded-xl border py-2 text-sm font-semibold transition-colors",
                        gender === g
                          ? "border-[var(--color-primary)] bg-[color-mix(in_oklab,var(--color-primary)_12%,transparent)] text-[var(--color-primary)]"
                          : "border-[var(--color-divider)] text-[var(--color-text-secondary)] hover:border-[var(--color-text-muted)]",
                      )}
                    >
                      {g === "ALL"
                        ? "Бүгд"
                        : g === "MALE"
                          ? "Эрэгтэй"
                          : "Эмэгтэй"}
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <Input
                  label="Хамгийн бага нас"
                  type="number"
                  min={13}
                  max={99}
                  value={minAge}
                  onChange={(e) => setMinAge(Number(e.target.value))}
                />
                <Input
                  label="Хамгийн их нас"
                  type="number"
                  min={13}
                  max={99}
                  value={maxAge}
                  onChange={(e) => setMaxAge(Number(e.target.value))}
                />
              </div>

              <Select
                label="Хот"
                value={city}
                onChange={(e) => setCity(e.target.value)}
              >
                {cities.map((c) => (
                  <option key={c} value={c}>
                    {c === "ALL" ? "Бүх хот" : c}
                  </option>
                ))}
              </Select>

              <div className="rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] p-4 text-xs text-[var(--color-text-primary)]">
                <div className="mb-1 font-semibold text-[var(--color-accent)]">
                  Тооцоолсон үнэ
                </div>
                <div className="flex items-baseline gap-2">
                  <span className="font-mono text-2xl font-extrabold">
                    {formatTugrik(costPerView)}
                  </span>
                  <span className="text-[var(--color-text-secondary)]">
                    / нэг үзэгч
                  </span>
                </div>
              </div>
            </CardBody>
          </Card>
        )}

        {step === "budget" && (
          <Card>
            <CardHeader
              title="Төсөв ба урамшуулал"
              description="Хэрэглэгчид хэдийг өгөх, платформ хэдийг авахыг тохируулах"
            />
            <CardBody className="space-y-5">
              <div className="grid grid-cols-2 gap-4">
                <Input
                  label="Нийт төсөв (₮)"
                  type="number"
                  min={100_000}
                  step={100_000}
                  value={totalBudget}
                  onChange={(e) => setTotalBudget(Number(e.target.value))}
                />
                <Input
                  label="Үзэгчид олгох урамшуулал (₮)"
                  type="number"
                  min={100}
                  step={100}
                  value={rewardPerUser}
                  onChange={(e) => setRewardPerUser(Number(e.target.value))}
                />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <SummaryTile
                  label="Нэг үзэгчийн зардал"
                  value={formatTugrik(costPerView)}
                />
                <SummaryTile
                  label="Платформын шимтгэл"
                  value={formatTugrik(platformFeePerView)}
                  tone="warn"
                />
                <SummaryTile
                  label="Хүрэх үзэгчийн тоо"
                  value={formatNumber(projectedReach)}
                  icon={<Calculator size={14} />}
                  tone="primary"
                />
              </div>

              <div className="rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] p-4 text-xs text-[var(--color-text-secondary)]">
                <b className="text-[var(--color-text-primary)]">Хэрхэн:</b>{" "}
                {formatTugrik(totalBudget)} төсөв ÷{" "}
                {formatTugrik(costPerView)} = ойролцоогоор{" "}
                <b className="text-[var(--color-text-primary)]">
                  {formatNumber(projectedReach)} үзэгч
                </b>{" "}
                судалгаа бөглөх боломжтой.
              </div>
            </CardBody>
          </Card>
        )}

        {step === "survey" && (
          <Card>
            <CardHeader
              title="Судалгааны асуултууд"
              description="2 – 3 асуулт зөвлөж байна. Хамгийн ихдээ 10."
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  leftIcon={<Plus size={14} />}
                  disabled={questions.length >= 10}
                  onClick={() =>
                    setQuestions((qs) => [
                      ...qs,
                      {
                        id: (qs.at(-1)?.id ?? 0) + 1,
                        prompt: "",
                        type: "SINGLE_CHOICE",
                        options: ["", ""],
                      },
                    ])
                  }
                >
                  Асуулт нэмэх
                </Button>
              }
            />
            <CardBody className="space-y-4">
              {questions.map((q, qi) => (
                <div
                  key={q.id}
                  className="rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] p-4"
                >
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex-1 space-y-3">
                      <Input
                        label={`Асуулт ${qi + 1}`}
                        value={q.prompt}
                        placeholder="Асуултаа бичнэ үү"
                        onChange={(e) =>
                          setQuestions((qs) =>
                            qs.map((x) =>
                              x.id === q.id
                                ? { ...x, prompt: e.target.value }
                                : x,
                            ),
                          )
                        }
                      />
                      <Select
                        label="Хариултын төрөл"
                        value={q.type}
                        onChange={(e) =>
                          setQuestions((qs) =>
                            qs.map((x) =>
                              x.id === q.id
                                ? {
                                    ...x,
                                    type: e.target
                                      .value as SurveyQ["type"],
                                  }
                                : x,
                            ),
                          )
                        }
                      >
                        <option value="SINGLE_CHOICE">
                          Ганц сонголт
                        </option>
                        <option value="MULTI_CHOICE">Олон сонголт</option>
                        <option value="TEXT">Чөлөөт текст</option>
                      </Select>

                      {q.type !== "TEXT" && (
                        <div className="space-y-2">
                          {q.options.map((opt, oi) => (
                            <Input
                              key={oi}
                              value={opt}
                              placeholder={`Сонголт ${oi + 1}`}
                              onChange={(e) =>
                                setQuestions((qs) =>
                                  qs.map((x) => {
                                    if (x.id !== q.id) return x;
                                    const next = [...x.options];
                                    next[oi] = e.target.value;
                                    return { ...x, options: next };
                                  }),
                                )
                              }
                            />
                          ))}
                          <Button
                            variant="ghost"
                            size="sm"
                            leftIcon={<Plus size={12} />}
                            onClick={() =>
                              setQuestions((qs) =>
                                qs.map((x) =>
                                  x.id === q.id
                                    ? {
                                        ...x,
                                        options: [...x.options, ""],
                                      }
                                    : x,
                                ),
                              )
                            }
                          >
                            Сонголт нэмэх
                          </Button>
                        </div>
                      )}
                    </div>
                    <button
                      onClick={() =>
                        setQuestions((qs) =>
                          qs.filter((x) => x.id !== q.id),
                        )
                      }
                      className="rounded-lg p-2 text-[var(--color-text-muted)] hover:bg-[var(--color-surface)] hover:text-[var(--color-danger)]"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              ))}
            </CardBody>
          </Card>
        )}

        {step === "review" && (
          <Card>
            <CardHeader
              title="Хянаж илгээх"
              description="Илгээсний дараа админ баталгаажуулна"
            />
            <CardBody className="space-y-4 text-sm">
              <ReviewRow label="Гарчиг" value={title || "—"} />
              <ReviewRow
                label="Видео"
                value={videoFile?.name ?? "Байршуулаагүй"}
              />
              <ReviewRow
                label="Хүйс"
                value={
                  gender === "ALL"
                    ? "Бүх хүйс"
                    : gender === "MALE"
                      ? "Эрэгтэй"
                      : "Эмэгтэй"
                }
              />
              <ReviewRow label="Нас" value={`${minAge} – ${maxAge}`} />
              <ReviewRow label="Хот" value={city === "ALL" ? "Бүх" : city} />
              <ReviewRow
                label="Төсөв"
                value={formatTugrik(totalBudget)}
                strong
              />
              <ReviewRow
                label="Урамшуулал / нэг үзэгч"
                value={formatTugrik(rewardPerUser)}
              />
              <ReviewRow
                label="Хүрэх үзэгчийн тоо (ойролцоогоор)"
                value={formatNumber(projectedReach)}
                strong
              />
              <ReviewRow
                label="Судалгааны асуулт"
                value={`${questions.length} ширхэг`}
              />
            </CardBody>
          </Card>
        )}
      </div>

      <div className="mt-6 flex items-center justify-between">
        <Button
          variant="secondary"
          disabled={!canPrev}
          onClick={() =>
            canPrev && setStep(steps[stepIndex - 1].id)
          }
          leftIcon={<ChevronLeft size={16} />}
        >
          Буцах
        </Button>
        {step === "review" ? (
          <Button leftIcon={<Check size={16} />} onClick={submit}>
            Илгээх
          </Button>
        ) : (
          <Button
            disabled={!canNext}
            onClick={() =>
              canNext && setStep(steps[stepIndex + 1].id)
            }
            rightIcon={<ChevronRight size={16} />}
          >
            Дараах
          </Button>
        )}
      </div>
    </>
  );
}

function Stepper({ current }: { current: number }) {
  return (
    <div className="flex items-center gap-2">
      {steps.map((s, i) => {
        const done = i < current;
        const active = i === current;
        return (
          <div key={s.id} className="flex flex-1 items-center gap-2">
            <div
              className={cn(
                "flex h-8 w-8 shrink-0 items-center justify-center rounded-full border text-xs font-bold",
                done &&
                  "border-[var(--color-success)] bg-[var(--color-success)] text-black",
                active &&
                  "border-[var(--color-primary)] bg-[var(--color-primary)] text-black",
                !done &&
                  !active &&
                  "border-[var(--color-divider)] text-[var(--color-text-muted)]",
              )}
            >
              {done ? <Check size={14} /> : i + 1}
            </div>
            <div
              className={cn(
                "hidden text-xs font-semibold sm:block",
                active
                  ? "text-[var(--color-text-primary)]"
                  : "text-[var(--color-text-secondary)]",
              )}
            >
              {s.label}
            </div>
            {i < steps.length - 1 && (
              <div className="flex-1 border-t border-dashed border-[var(--color-divider)]" />
            )}
          </div>
        );
      })}
    </div>
  );
}

function SummaryTile({
  label,
  value,
  tone = "neutral",
  icon,
}: {
  label: string;
  value: string;
  tone?: "neutral" | "primary" | "warn";
  icon?: React.ReactNode;
}) {
  const toneCls = {
    neutral: "border-[var(--color-divider)] bg-[var(--color-surface-elevated)]",
    primary:
      "border-[color-mix(in_oklab,var(--color-primary)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)]",
    warn: "border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)]",
  }[tone];

  return (
    <div className={cn("rounded-xl border p-3", toneCls)}>
      <div className="mb-1 flex items-center gap-1.5 text-[10px] uppercase tracking-wide text-[var(--color-text-secondary)]">
        {icon} {label}
      </div>
      <div className="font-mono text-lg font-bold text-[var(--color-text-primary)]">
        {value}
      </div>
    </div>
  );
}

function ReviewRow({
  label,
  value,
  strong,
}: {
  label: string;
  value: string;
  strong?: boolean;
}) {
  return (
    <div className="flex items-center justify-between border-b border-[var(--color-divider)] pb-3 last:border-0 last:pb-0">
      <span className="text-[var(--color-text-secondary)]">{label}</span>
      <span
        className={cn(
          "font-mono",
          strong
            ? "text-lg font-bold text-[var(--color-primary)]"
            : "text-[var(--color-text-primary)]",
        )}
      >
        {value}
      </span>
    </div>
  );
}
