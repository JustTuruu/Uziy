"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Check,
  ChevronLeft,
  ChevronRight,
  CircleAlert,
  ClipboardList,
  Clock,
  LoaderCircle,
  Plus,
  RotateCcw,
  Trash2,
  Upload,
  Video,
} from "lucide-react";
import {
  CampaignBudgetFields,
  DEFAULT_BUDGET_FIELDS,
  pricingFromFields,
  type BudgetFieldsValue,
} from "@/components/campaign-budget-fields";
import { CampaignPaymentCard } from "@/components/campaign-payment-card";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input, NumericInput, Select } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import {
  ApiError,
  auth,
  companyApi,
  platformSettingsApi,
  type Campaign,
  type PlatformSettings,
} from "@/lib/api";
import { pricingErrorMessage, pricingRequestFields } from "@/lib/pricing";
import {
  cn,
  formatDuration,
  formatNumber,
  formatTugrik,
  parseIntInput,
} from "@/lib/utils";
import {
  MAX_VIDEO_SECONDS,
  MIN_VIDEO_SECONDS,
  describeVideoLength,
  isVideoLengthAllowed,
  readVideoDuration,
  type VideoLengthStatus,
} from "@/lib/video";

type CampaignKind = "VIDEO" | "SURVEY_ONLY";
type Step =
  | "type"
  | "video"
  | "targeting"
  | "budget"
  | "survey"
  | "review"
  | "payment";

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

  // Type toggle (drives visible steps; pricing is the same for both kinds)
  const [kind, setKind] = useState<CampaignKind>("VIDEO");
  const [step, setStep] = useState<Step>("type");

  // Commission % + minimum reward, set by the Super Admin. Needed to preview
  // the price on the budget step; the server re-prices on create anyway.
  const [platformSettings, setPlatformSettings] =
    useState<PlatformSettings | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [settingsAttempt, setSettingsAttempt] = useState(0);

  // Step: video
  const [title, setTitle] = useState("");
  const [videoFile, setVideoFile] = useState<File | null>(null);
  // The video length is read from the picked file's metadata
  // (lib/video.ts) — companies never type it. null until a readable video
  // is picked.
  const [duration, setDuration] = useState<number | null>(null);
  const [durationStatus, setDurationStatus] =
    useState<VideoLengthStatus>("idle");
  const videoPickSeq = useRef(0);

  const pickVideo = (file: File | null) => {
    const seq = ++videoPickSeq.current; // ignore results of an older pick
    setVideoFile(file);
    setDuration(null);
    if (!file) {
      setDurationStatus("idle");
      return;
    }
    setDurationStatus("reading");
    readVideoDuration(file).then(
      (seconds) => {
        if (seq !== videoPickSeq.current) return;
        setDuration(seconds);
        setDurationStatus("ready");
      },
      () => {
        if (seq !== videoPickSeq.current) return;
        setDurationStatus("error");
      },
    );
  };
  const videoLength = describeVideoLength(durationStatus, duration);

  // Number fields keep the raw text so they can be cleared while typing
  // (numeric state would snap an empty field back to "0").

  // Step: targeting
  const [gender, setGender] = useState<"ALL" | "MALE" | "FEMALE">("ALL");
  const [minAgeText, setMinAgeText] = useState("18");
  const [maxAgeText, setMaxAgeText] = useState("45");
  const minAge = parseIntInput(minAgeText);
  const maxAge = parseIntInput(maxAgeText);
  const [city, setCity] = useState<string>("Улаанбаатар");

  // Step: budget. The company enters a total budget plus EITHER a viewer
  // count or a per-viewer reward; the other is derived (lib/pricing.ts).
  const [budgetFields, setBudgetFields] =
    useState<BudgetFieldsValue>(DEFAULT_BUDGET_FIELDS);
  const pricing = useMemo(
    () =>
      platformSettings ? pricingFromFields(budgetFields, platformSettings) : null,
    [budgetFields, platformSettings],
  );

  // Set once the campaign exists on the server (status AWAITING_PAYMENT);
  // from then on the wizard only shows the payment step.
  const [created, setCreated] = useState<Campaign | null>(null);

  // Step: survey. Seed with one empty question so the user sees the form
  // structure — but no pre-filled text: they should type their own prompt and
  // answers, guided only by placeholders.
  const [questions, setQuestions] = useState<SurveyQ[]>([
    {
      id: 1,
      prompt: "",
      type: "SINGLE_CHOICE",
      options: ["", ""],
    },
  ]);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    platformSettingsApi
      .get()
      .then((s) => {
        setPlatformSettings(s);
        setLoadError(null);
      })
      .catch((e) =>
        setLoadError(e instanceof Error ? e.message : "Алдаа гарлаа"),
      );
  }, [router, settingsAttempt]);

  const retryLoadSettings = () => {
    setLoadError(null);
    setSettingsAttempt((n) => n + 1);
  };

  // Video campaigns skip nothing. Survey-only skips the "video" step. The
  // last step (payment) is only reachable by creating the campaign.
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
            { id: "payment", label: "Төлбөр" },
          ]
        : [
            { id: "type", label: "Төрөл" },
            { id: "targeting", label: "Зорилтот" },
            { id: "budget", label: "Төсөв" },
            { id: "survey", label: "Судалгаа" },
            { id: "review", label: "Хянах" },
            { id: "payment", label: "Төлбөр" },
          ],
    [kind],
  );

  const stepIndex = steps.findIndex((s) => s.id === step);
  const reviewIndex = steps.findIndex((s) => s.id === "review");
  const canPrev = stepIndex > 0 && step !== "payment";
  // "Дараах" never leads past review — only "Үүсгэх" opens the payment step.
  const canNext = stepIndex < reviewIndex;
  // Settings loaded and the budget/viewers/reward combination is valid.
  const pricingOk = pricing !== null && pricing.error === null;

  const goNext = () => {
    if (canNext) setStep(steps[stepIndex + 1].id);
  };
  const goPrev = () => {
    if (canPrev) setStep(steps[stepIndex - 1].id);
  };

  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const submit = async () => {
    setSubmitError(null);

    if (created) return; // already created — never create twice
    if (!title.trim()) {
      setSubmitError("Гарчиг заавал бөглөнө үү");
      return;
    }
    if (!platformSettings || !pricing) {
      setSubmitError("Шимтгэлийн тохиргоо ачаалагдаж дуусаагүй байна");
      return;
    }
    if (kind === "VIDEO" && !videoFile) {
      setSubmitError("Видео файлаа сонгоно уу");
      return;
    }
    if (kind === "VIDEO" && !isVideoLengthAllowed(duration)) {
      setSubmitError(
        durationStatus === "ready"
          ? `Видеоны урт ${formatDuration(MIN_VIDEO_SECONDS)}–` +
              `${formatDuration(MAX_VIDEO_SECONDS)} хооронд байх ёстой`
          : "Видеоны уртыг уншиж чадсангүй — өөр MP4 файл сонгоно уу",
      );
      return;
    }
    // Number fields can now be left blank (blank counts as 0), so catch
    // empty/out-of-range values here instead of sending them to the API.
    if (minAge < 13 || maxAge > 99 || minAge > maxAge) {
      setSubmitError(
        "Нас 13-99 хооронд, бага нас нь их наснаас хэтрэхгүй байх ёстой",
      );
      return;
    }
    if (pricing.error) {
      setSubmitError(
        pricingErrorMessage(pricing.error, platformSettings.minRewardPerViewer),
      );
      return;
    }
    if (questions.length === 0) {
      setSubmitError("Хамгийн багадаа 1 асуулт нэмнэ үү");
      return;
    }
    // Now that we no longer seed the survey with example content, catch the
    // easy case where the user left the fields blank before hitting submit.
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      if (!q.prompt.trim()) {
        setSubmitError(`Асуулт ${i + 1}: асуултын текстийг бөглөнө үү`);
        return;
      }
      if (q.type !== "TEXT") {
        const filled = q.options.filter((o) => o.trim().length > 0);
        if (filled.length < 2) {
          setSubmitError(
            `Асуулт ${i + 1}: хамгийн багадаа 2 хариулт бөглөнө үү`,
          );
          return;
        }
      }
    }

    setSubmitting(true);
    try {
      // NOTE: video file upload is not wired yet — until the FFmpeg worker
      // exists, we send an empty videoUrl for video campaigns too and the
      // company can attach a hosted URL later.
      // The server prices the campaign itself from the current commission
      // settings: we send the budget plus ONLY the field the company drove
      // (viewer count or per-viewer reward). The returned campaign — not
      // this preview — is what the invoice shows.
      const campaign = await companyApi.create({
        title: title.trim(),
        hasVideo: kind === "VIDEO",
        videoUrl: "",
        durationSeconds: kind === "VIDEO" ? (duration ?? 0) : 0,
        targetGender: gender,
        minAge, maxAge,
        targetCity: city,
        totalBudget: pricing.budget,
        ...pricingRequestFields(pricing),
        questions: questions.map((q) => ({
          prompt: q.prompt,
          type: q.type,
          options: q.type === "TEXT" ? [] : q.options.filter(Boolean),
          required: true,
        })),
      });
      setCreated(campaign);
      setStep("payment");
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        auth.clear();
        router.replace("/login");
        return;
      }
      setSubmitError(e instanceof ApiError ? e.message : "Илгээхэд алдаа гарлаа");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Шинэ аян үүсгэх"
        description={
          step === "payment"
            ? "Аян үүслээ. Төлбөрөө төлснөөр админы шалгалтад орно."
            : kind === "VIDEO"
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
                hint="Компанийн видео хэрэглэгчид харагдана. Видеог бүтэн үзсэний дараа судалгаанд хариулна."
                active={kind === "VIDEO"}
                onClick={() => setKind("VIDEO")}
              />
              <KindCard
                icon={<ClipboardList size={20} />}
                title="Судалгаа зөвхөн"
                hint="Видеогүй. Хэрэглэгч шууд судалгаанд хариулна."
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
                    onChange={(e) => pickVideo(e.target.files?.[0] ?? null)}
                  />
                  <label htmlFor="video-input">
                    <span className="mt-2 inline-flex cursor-pointer items-center rounded-xl bg-[var(--color-surface-elevated)] px-3 py-1.5 text-xs font-semibold text-[var(--color-text-primary)]">
                      Файл сонгох
                    </span>
                  </label>
                </div>
              </label>

              <div
                aria-live="polite"
                className={cn(
                  "flex items-center gap-2 rounded-xl border px-4 py-3 text-sm",
                  videoLength.tone === "error"
                    ? "border-[color-mix(in_oklab,var(--color-danger)_40%,transparent)] bg-[color-mix(in_oklab,var(--color-danger)_8%,transparent)] text-[var(--color-danger)]"
                    : videoLength.tone === "ok"
                      ? "border-[var(--color-divider)] text-[var(--color-text-primary)]"
                      : "border-[var(--color-divider)] text-[var(--color-text-secondary)]",
                )}
              >
                {videoLength.tone === "busy" ? (
                  <LoaderCircle size={16} className="shrink-0 animate-spin" />
                ) : videoLength.tone === "error" ? (
                  <CircleAlert size={16} className="shrink-0" />
                ) : (
                  <Clock size={16} className="shrink-0" />
                )}
                <span className={videoLength.tone === "ok" ? "font-semibold" : undefined}>
                  {videoLength.text}
                </span>
              </div>
            </CardBody>
          </Card>
        )}

        {step === "targeting" && (
          <Card>
            <CardHeader
              title="Зорилтот үзэгч"
              description={
                kind === "VIDEO"
                  ? "Аяныг хэнд харуулахаа сонгоно уу"
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
                <NumericInput
                  label="Хамгийн бага нас"
                  maxLength={2}
                  value={minAgeText}
                  onValueChange={setMinAgeText}
                />
                <NumericInput
                  label="Хамгийн их нас"
                  maxLength={2}
                  value={maxAgeText}
                  onValueChange={setMaxAgeText}
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

            </CardBody>
          </Card>
        )}

        {step === "budget" && (
          <Card>
            <CardHeader
              title="Төсөв ба урамшуулал"
              description="Нийт төсвөө оруулаад хүрэх үзэгчийн тоо эсвэл нэг үзэгчид олгох урамшууллаа сонгоно уу. Данс цэнэглэх шаардлагагүй — аяны төлбөрийг хамгийн сүүлд төлнө."
            />
            <CardBody>
              {platformSettings ? (
                <CampaignBudgetFields
                  value={budgetFields}
                  onChange={setBudgetFields}
                  settings={platformSettings}
                />
              ) : loadError ? (
                <div
                  role="alert"
                  className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]"
                >
                  <span>Шимтгэлийн тохиргоо ачаалахад алдаа гарлаа: {loadError}</span>
                  <Button
                    variant="secondary"
                    size="sm"
                    leftIcon={<RotateCcw size={12} />}
                    onClick={retryLoadSettings}
                  >
                    Дахин оролдох
                  </Button>
                </div>
              ) : (
                <div className="flex items-center gap-2 text-sm text-[var(--color-text-muted)]">
                  <LoaderCircle size={16} className="animate-spin" />
                  Шимтгэлийн тохиргоо ачаалж байна...
                </div>
              )}
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
                    <div className="flex-1 space-y-4">
                      <Input
                        label={`Асуулт ${qi + 1}`}
                        value={q.prompt}
                        placeholder="Асуулт"
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
                        <div className="rounded-lg border border-[var(--color-divider)] bg-[var(--color-surface)] p-3">
                          <div className="mb-2 text-[10px] font-semibold uppercase tracking-wide text-[var(--color-text-secondary)]">
                            Хариултын сонголтууд
                          </div>
                          <div className="space-y-2">
                            {q.options.map((opt, oi) => (
                              <Input
                                key={oi}
                                value={opt}
                                placeholder={`Хариулт ${oi + 1}`}
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
                              Хариулт нэмэх
                            </Button>
                          </div>
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
              title="Хянаж үүсгэх"
              description="Үүсгэсний дараа төлбөрөө төлнө. Төлбөр төлөгдсөний дараа админ шалгаж баталгаажуулна."
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
              {kind === "VIDEO" && (
                <ReviewRow
                  label="Урт"
                  value={duration === null ? "—" : formatDuration(duration)}
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
                label="Судалгааны асуулт"
                value={`${questions.length} ширхэг`}
              />
              <ReviewRow
                label="Нийт төсөв"
                value={pricingOk ? formatTugrik(pricing.payable) : "—"}
              />
              <ReviewRow
                label="Хүрэх үзэгч"
                value={pricingOk ? formatNumber(pricing.targetViewers) : "—"}
              />
              <ReviewRow
                label="Нэг үзэгчид олгох урамшуулал"
                value={pricingOk ? formatTugrik(pricing.rewardPerViewer) : "—"}
              />
              <ReviewRow
                label={
                  pricing
                    ? `Платформын шимтгэл (${pricing.commissionPercent}%)`
                    : "Платформын шимтгэл"
                }
                value={pricingOk ? formatTugrik(pricing.commissionTotal) : "—"}
              />
              <ReviewRow
                label="Төлөх дүн"
                value={pricingOk ? formatTugrik(pricing.payable) : "—"}
                strong
              />
              {pricingOk && pricing.unused > 0 && (
                <div className="text-xs text-[var(--color-text-muted)]">
                  Таны оруулсан {formatTugrik(pricing.budget)} төсвөөс үлдэгдэл{" "}
                  {formatTugrik(pricing.unused)} төлбөрт орохгүй.
                </div>
              )}
              {submitError && (
                <div
                  role="alert"
                  className="mt-2 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]"
                >
                  {submitError}
                </div>
              )}
            </CardBody>
          </Card>
        )}

        {step === "payment" && created && (
          <CampaignPaymentCard campaign={created} variant="wizard" />
        )}
      </div>

      {/* Once the campaign exists it can't be edited from here any more, so
          the payment step has no Back/Next bar — only the payment card. */}
      {step !== "payment" && (
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
            <Button
              leftIcon={<Check size={16} />}
              onClick={submit}
              disabled={submitting || !pricingOk}
            >
              {submitting ? "Үүсгэж байна..." : "Үүсгэх"}
            </Button>
          ) : (
            <Button
              disabled={
                !canNext ||
                (step === "type" && !title.trim()) ||
                (step === "video" && !isVideoLengthAllowed(duration)) ||
                (step === "budget" && !pricingOk)
              }
              onClick={goNext}
              rightIcon={<ChevronRight size={16} />}
            >
              Дараах
            </Button>
          )}
        </div>
      )}
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
