"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import {
  Calculator,
  Check,
  ChevronLeft,
  ChevronRight,
  ClipboardList,
  Plus,
  Trash2,
  Upload,
  Video,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import {
  ApiError,
  auth,
  platformSettingsApi,
  type PlatformSettings,
} from "@/lib/api";
import { cn, formatNumber, formatTugrik } from "@/lib/utils";

type CampaignKind = "VIDEO" | "SURVEY_ONLY";
type Step = "type" | "video" | "targeting" | "budget" | "survey" | "review";

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

/** Cost-per-view for video campaigns — grows with targeting precision. */
export function computeVideoCostPerView(input: {
  gender: "ALL" | "MALE" | "FEMALE";
  minAge: number;
  maxAge: number;
  city: string;
}): number {
  let cost = 500;
  if (input.gender !== "ALL") cost += 200;
  if (input.maxAge - input.minAge <= 10) cost += 150;
  if (input.city !== "ALL") cost += 200;
  return cost;
}

export default function NewCampaignPage() {
  const router = useRouter();

  // Type toggle (drives visible steps + pricing model)
  const [kind, setKind] = useState<CampaignKind>("VIDEO");
  const [step, setStep] = useState<Step>("type");

  const [platformSettings, setPlatformSettings] =
    useState<PlatformSettings | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  // Step: video
  const [title, setTitle] = useState("");
  const [videoFile, setVideoFile] = useState<File | null>(null);
  const [duration, setDuration] = useState<number>(30);

  // Step: targeting
  const [gender, setGender] = useState<"ALL" | "MALE" | "FEMALE">("ALL");
  const [minAge, setMinAge] = useState(18);
  const [maxAge, setMaxAge] = useState(45);
  const [city, setCity] = useState<string>("Улаанбаатар");

  // Step: budget
  const [totalBudget, setTotalBudget] = useState(1_000_000);
  const [rewardPerUser, setRewardPerUser] = useState(600);

  // Step: survey
  const [questions, setQuestions] = useState<SurveyQ[]>([
    {
      id: 1,
      prompt: "Танай brand-ийг таньж байна уу?",
      type: "SINGLE_CHOICE",
      options: ["Тийм", "Дунд зэрэг", "Үгүй"],
    },
  ]);

  // Load platform settings once; needed for SURVEY_ONLY pricing display.
  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    platformSettingsApi
      .get()
      .then(setPlatformSettings)
      .catch((e) => setLoadError(e instanceof Error ? e.message : "Алдаа"));
  }, [router]);

  // Video campaigns skip nothing. Survey-only skips the "video" step.
  const steps = useMemo<{ id: Step; label: string }[]>(
    () =>
      kind === "VIDEO"
        ? [
            { id: "type", label: "Төрөл" },
            { id: "video", label: "Видео" },
            { id: "targeting", label: "Зорилтот" },
            { id: "budget", label: "Төсөв" },
            { id: "survey", label: "Судалгаа" },
            { id: "review", label: "Хянах" },
          ]
        : [
            { id: "type", label: "Төрөл" },
            { id: "targeting", label: "Зорилтот" },
            { id: "budget", label: "Төсөв" },
            { id: "survey", label: "Судалгаа" },
            { id: "review", label: "Хянах" },
          ],
    [kind],
  );

  // Derived pricing.
  const videoCostPerView = useMemo(
    () => computeVideoCostPerView({ gender, minAge, maxAge, city }),
    [gender, minAge, maxAge, city],
  );
  const costPerUnit =
    kind === "VIDEO"
      ? videoCostPerView
      : platformSettings?.surveyOnlyCostPerResponse ?? 0;
  const effectiveReward =
    kind === "VIDEO"
      ? rewardPerUser
      : platformSettings?.surveyOnlyRewardPerUser ?? 0;
  const platformFeePerUnit = Math.max(0, costPerUnit - effectiveReward);
  const projectedReach = costPerUnit > 0 ? Math.floor(totalBudget / costPerUnit) : 0;

  const stepIndex = steps.findIndex((s) => s.id === step);
  const canPrev = stepIndex > 0;
  const canNext = stepIndex < steps.length - 1;

  const goNext = () => {
    if (canNext) setStep(steps[stepIndex + 1].id);
  };
  const goPrev = () => {
    if (canPrev) setStep(steps[stepIndex - 1].id);
  };

  const submit = async () => {
    // TODO: POST /company/campaigns (multipart video for VIDEO; JSON for SURVEY_ONLY).
    // Backend enforces hasVideo=false → durationSeconds=0, videoUrl="", questions.size >= 1
    await new Promise((r) => setTimeout(r, 400));
    router.push("/company/campaigns");
  };

  return (
    <>
      <PageHeader
        title="Шинэ кампани үүсгэх"
        description={
          kind === "VIDEO"
            ? "Видео байршуулж, зорилтот үзэгчээ тодорхойлно уу"
            : "Видеогүй судалгаа кампани — хэрэглэгч видео үзэлгүй шууд хариулна"
        }
      />

      <Stepper steps={steps} current={stepIndex} />

      <div className="mt-8">
        {step === "type" && (
          <Card>
            <CardHeader
              title="Кампанийн төрлөө сонго"
              description="Дараах алхмууд төрлийн дагуу өөрчлөгдөнө"
            />
            <CardBody className="grid grid-cols-1 gap-4 md:grid-cols-2">
              <KindCard
                icon={<Video size={20} />}
                title="Видеотой кампани"
                hint="Компанийн видео хэрэглэгчид харагдана. Үнэ нь зорилтот нарийвчлалаас хамааран өөрчлөгдөнө."
                active={kind === "VIDEO"}
                onClick={() => setKind("VIDEO")}
              />
              <KindCard
                icon={<ClipboardList size={20} />}
                title="Судалгаа зөвхөн"
                hint={
                  platformSettings
                    ? `Видеогүй. Үнэ: ${formatTugrik(
                        platformSettings.surveyOnlyCostPerResponse,
                      )} / хариулт (админаас тогтоосон).`
                    : "Видеогүй. Үнэ админ дээр төвлөрч тохируулагдана."
                }
                active={kind === "SURVEY_ONLY"}
                onClick={() => setKind("SURVEY_ONLY")}
              />
              <div className="md:col-span-2">
                <Input
                  label="Кампанийн гарчиг"
                  placeholder="Ж-нь: Шинэ 5G багц"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                />
              </div>
              {loadError && (
                <div className="md:col-span-2 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]">
                  Судалгааны үнэ ачаалахад алдаа: {loadError}
                </div>
              )}
            </CardBody>
          </Card>
        )}

        {step === "video" && kind === "VIDEO" && (
          <Card>
            <CardHeader
              title="Видео байршуулах"
              description="MP4 форматтай, 30 сек – 2 минутын урттай байх"
            />
            <CardBody className="space-y-5">
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
                    onChange={(e) => setVideoFile(e.target.files?.[0] ?? null)}
                  />
                  <label htmlFor="video-input">
                    <span className="mt-2 inline-flex cursor-pointer items-center rounded-xl bg-[var(--color-surface-elevated)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-primary)]">
                      Файл сонгох
                    </span>
                  </label>
                </div>
              </label>

              <Input
                label="Урт (секунд)"
                type="number"
                min={5}
                max={180}
                value={duration}
                onChange={(e) => setDuration(Number(e.target.value))}
                hint="5 – 180 сек"
              />
            </CardBody>
          </Card>
        )}

        {step === "targeting" && (
          <Card>
            <CardHeader
              title="Зорилтот үзэгч"
              description={
                kind === "VIDEO"
                  ? "Нарийвчлал өндөр байх тусам нэг үзэгчийн үнэ өснө"
                  : "Судалгаа хэнд илгээх вэ"
              }
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
                      {g === "ALL" ? "Бүгд" : g === "MALE" ? "Эрэгтэй" : "Эмэгтэй"}
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

              {kind === "VIDEO" && (
                <div className="rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] p-4 text-xs text-[var(--color-text-primary)]">
                  <div className="mb-1 font-semibold text-[var(--color-accent)]">
                    Тооцоолсон үнэ
                  </div>
                  <div className="flex items-baseline gap-2">
                    <span className="font-mono text-2xl font-extrabold">
                      {formatTugrik(costPerUnit)}
                    </span>
                    <span className="text-[var(--color-text-secondary)]">
                      / нэг үзэгч
                    </span>
                  </div>
                </div>
              )}
            </CardBody>
          </Card>
        )}

        {step === "budget" && (
          <Card>
            <CardHeader
              title="Төсөв ба урамшуулал"
              description={
                kind === "VIDEO"
                  ? "Хэрэглэгчид хэдийг өгөх, платформ хэдийг авахыг тохируулах"
                  : "Судалгааны үнэ платформоор төвлөрсөн тохируулагдсан"
              }
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
                {kind === "VIDEO" ? (
                  <Input
                    label="Үзэгчид олгох урамшуулал (₮)"
                    type="number"
                    min={100}
                    step={100}
                    value={rewardPerUser}
                    onChange={(e) => setRewardPerUser(Number(e.target.value))}
                  />
                ) : (
                  <div>
                    <div className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                      Хэрэглэгчид олгох (админ тогтоосон)
                    </div>
                    <div className="rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] px-4 py-2.5 font-mono text-sm text-[var(--color-text-primary)]">
                      {formatTugrik(effectiveReward)}
                    </div>
                  </div>
                )}
              </div>

              <div className="grid grid-cols-3 gap-3">
                <SummaryTile
                  label={
                    kind === "VIDEO"
                      ? "Нэг үзэгчийн зардал"
                      : "Нэг хариултын зардал"
                  }
                  value={formatTugrik(costPerUnit)}
                />
                <SummaryTile
                  label="Платформын шимтгэл"
                  value={formatTugrik(platformFeePerUnit)}
                  tone="warn"
                />
                <SummaryTile
                  label={
                    kind === "VIDEO"
                      ? "Хүрэх үзэгчийн тоо"
                      : "Хүлээгдэж буй хариултын тоо"
                  }
                  value={formatNumber(projectedReach)}
                  icon={<Calculator size={14} />}
                  tone="primary"
                />
              </div>

              <div className="rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] p-4 text-xs text-[var(--color-text-secondary)]">
                <b className="text-[var(--color-text-primary)]">Хэрхэн:</b>{" "}
                {formatTugrik(totalBudget)} төсөв ÷ {formatTugrik(costPerUnit)} =
                ойролцоогоор{" "}
                <b className="text-[var(--color-text-primary)]">
                  {formatNumber(projectedReach)}{" "}
                  {kind === "VIDEO" ? "үзэгч" : "хариулт"}
                </b>{" "}
                хүлээж авах боломжтой.
              </div>
            </CardBody>
          </Card>
        )}

        {step === "survey" && (
          <Card>
            <CardHeader
              title="Судалгааны асуултууд"
              description={
                kind === "SURVEY_ONLY"
                  ? "Дор хаяж 1 асуулт заавал. Дээд тал нь 20."
                  : "2 – 3 асуулт зөвлөж байна. Дээд тал нь 20."
              }
              action={
                <Button
                  variant="secondary"
                  size="sm"
                  leftIcon={<Plus size={14} />}
                  disabled={questions.length >= 20}
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
                                    type: e.target.value as SurveyQ["type"],
                                  }
                                : x,
                            ),
                          )
                        }
                      >
                        <option value="SINGLE_CHOICE">Ганц сонголт</option>
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
                                    ? { ...x, options: [...x.options, ""] }
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
                        setQuestions((qs) => qs.filter((x) => x.id !== q.id))
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
              <ReviewRow
                label="Төрөл"
                value={kind === "VIDEO" ? "Видеотой" : "Судалгаа зөвхөн"}
              />
              <ReviewRow label="Гарчиг" value={title || "—"} />
              {kind === "VIDEO" && (
                <ReviewRow
                  label="Видео"
                  value={videoFile?.name ?? "Байршуулаагүй"}
                />
              )}
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
                label={
                  kind === "VIDEO" ? "Урамшуулал / нэг үзэгч" : "Урамшуулал / нэг хариулт"
                }
                value={formatTugrik(effectiveReward)}
              />
              <ReviewRow
                label={
                  kind === "VIDEO"
                    ? "Хүрэх үзэгчийн тоо (ойролцоогоор)"
                    : "Хүлээгдэж буй хариултын тоо (ойролцоогоор)"
                }
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
          onClick={goPrev}
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
            disabled={!canNext || (step === "type" && !title.trim())}
            onClick={goNext}
            rightIcon={<ChevronRight size={16} />}
          >
            Дараах
          </Button>
        )}
      </div>
    </>
  );
}

function Stepper({
  steps,
  current,
}: {
  steps: { id: Step; label: string }[];
  current: number;
}) {
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

function KindCard({
  icon,
  title,
  hint,
  active,
  onClick,
}: {
  icon: React.ReactNode;
  title: string;
  hint: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex flex-col items-start gap-2 rounded-xl border p-4 text-left transition-colors",
        active
          ? "border-[var(--color-primary)] bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)]"
          : "border-[var(--color-divider)] bg-[var(--color-surface)] hover:border-[var(--color-text-muted)]",
      )}
    >
      <span
        className={cn(
          active
            ? "text-[var(--color-primary)]"
            : "text-[var(--color-text-secondary)]",
        )}
      >
        {icon}
      </span>
      <span className="text-sm font-bold text-[var(--color-text-primary)]">
        {title}
      </span>
      <span className="text-xs text-[var(--color-text-secondary)]">{hint}</span>
    </button>
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
