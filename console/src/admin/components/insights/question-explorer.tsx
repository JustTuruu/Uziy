import { useEffect, useState } from "react";
import { Download } from "lucide-react";
import { Badge, Button, Card, CardBody, CardHeader, Select } from "@uziy/ui";
import {
  insightsApi,
  type InsightDistribution,
  type InsightFilter,
  type InsightQuestion,
  type InsightSegments,
} from "@admin/lib/api";
import { hiddenLabel, peopleLabel } from "./insight-format";
import { ShareBar } from "./share-bar";

export const ANY = "";
export const GENDER_OPTIONS = [
  { value: ANY, label: "Бүх хүйс" },
  { value: "MALE", label: "Эрэгтэй" },
  { value: "FEMALE", label: "Эмэгтэй" },
];

/** The API filter for the picked select values ("" = any). */
export function toFilter(gender: string, ageBand: string, city: string): InsightFilter {
  return {
    gender: gender === "MALE" || gender === "FEMALE" ? gender : null,
    ageBand: ageBand || null,
    city: city || null,
  };
}

/** Saves [text] as a file through the browser (UTF-8 CSV for Excel). */
export function downloadCsv(text: string, fileName: string) {
  const url = URL.createObjectURL(new Blob([text], { type: "text/csv;charset=utf-8" }));
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  a.click();
  URL.revokeObjectURL(url);
}

/**
 * Pick a choice/rating question, narrow by gender / age band / aimag and read
 * the answer shares; segments and a CSV export underneath.
 */
export function QuestionExplorer({
  questions,
  ageBands,
  cities,
  minGroupSize,
}: {
  questions: InsightQuestion[];
  ageBands: string[];
  cities: string[];
  minGroupSize: number;
}) {
  const [selected, setSelected] = useState<number | null>(null);
  const [gender, setGender] = useState(ANY);
  const [ageBand, setAgeBand] = useState(ANY);
  const [city, setCity] = useState(ANY);
  const [distribution, setDistribution] = useState<InsightDistribution | null>(null);
  const [segments, setSegments] = useState<InsightSegments | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [exporting, setExporting] = useState(false);

  useEffect(() => {
    if (selected === null) return;
    let live = true;
    insightsApi
      .distribution(selected, toFilter(gender, ageBand, city))
      .then((d) => live && setDistribution(d))
      .catch((e) => live && setError(e instanceof Error ? e.message : "Алдаа гарлаа"));
    return () => {
      live = false;
    };
  }, [selected, gender, ageBand, city]);

  useEffect(() => {
    if (selected === null) return;
    let live = true;
    insightsApi
      .segments(selected)
      .then((s) => live && setSegments(s))
      .catch((e) => live && setError(e instanceof Error ? e.message : "Алдаа гарлаа"));
    return () => {
      live = false;
    };
  }, [selected]);

  function pick(id: number) {
    setError(null);
    setDistribution(null);
    setSegments(null);
    setSelected(id);
  }

  async function exportCsv() {
    if (selected === null || exporting) return;
    setExporting(true);
    try {
      downloadCsv(await insightsApi.exportCsv(selected), `uziy-statistic-${selected}.csv`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Татаж чадсангүй");
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader
          title="Асуултууд"
          description="Сонголттой болон үнэлгээний асуултууд. Чөлөөт текст статистикт ордоггүй."
        />
        <CardBody className="p-0">
          {questions.length === 0 ? (
            <p className="px-5 py-6 text-sm text-[var(--color-text-secondary)]">
              Асуулт алга.
            </p>
          ) : (
            <ul className="divide-y divide-[var(--color-divider)]">
              {questions.map((q) => (
                <li key={q.questionId}>
                  <button
                    type="button"
                    onClick={() => pick(q.questionId)}
                    aria-pressed={selected === q.questionId}
                    className="flex w-full items-center justify-between gap-4 px-5 py-3 text-left hover:bg-[var(--color-surface-elevated)] aria-pressed:bg-[var(--color-surface-elevated)]"
                  >
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-medium">{q.prompt}</span>
                      <span className="block truncate text-xs text-[var(--color-text-secondary)]">
                        {q.surveyTitle} · {q.companyName}
                      </span>
                    </span>
                    <span className="flex shrink-0 items-center gap-3">
                      <span className="text-xs tabular-nums text-[var(--color-text-secondary)]">
                        ≈ {q.respondents}
                      </span>
                      <Badge tone={q.reportable ? "success" : "neutral"}>
                        {q.reportable ? "Тайлагнана" : `${hiddenLabel(minGroupSize)} хүн`}
                      </Badge>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </Card>

      {error && (
        <p role="alert" className="text-sm text-[var(--color-danger)]">
          {error}
        </p>
      )}

      {selected !== null && (
        <Card>
          <CardHeader
            title={distribution?.prompt ?? "Ачаалж байна…"}
            description="Шүүлтүүрээр бүлгээ сонгоно уу"
            action={
              <Button
                variant="secondary"
                disabled={exporting}
                onClick={exportCsv}
                leftIcon={<Download size={15} />}
              >
                {exporting ? "Татаж байна…" : "CSV татах"}
              </Button>
            }
          />
          <CardBody className="space-y-6">
            <div className="grid gap-3 md:grid-cols-3">
              <Select label="Хүйс" options={GENDER_OPTIONS} value={gender} onValueChange={setGender} />
              <Select
                label="Нас"
                options={[{ value: ANY, label: "Бүх нас" }, ...ageBands.map((b) => ({ value: b, label: b }))]}
                value={ageBand}
                onValueChange={setAgeBand}
              />
              <Select
                label="Аймаг / хот"
                options={[{ value: ANY, label: "Бүх аймаг, хот" }, ...cities.map((c) => ({ value: c, label: c }))]}
                value={city}
                onValueChange={setCity}
              />
            </div>
            {distribution &&
              (distribution.suppressed ? (
                <p className="rounded-xl border border-[var(--color-divider)] px-4 py-3 text-sm text-[var(--color-text-secondary)]">
                  Энэ бүлэгт {minGroupSize}-аас цөөн хүн байгаа (эсвэл үлдсэн хэсэг нь цөөн) тул хувийн нууцыг хамгаалж
                  харуулахгүй.
                </p>
              ) : (
                <div className="space-y-3">
                  <p className="text-xs text-[var(--color-text-secondary)]">
                    {peopleLabel(distribution.people, minGroupSize)}
                  </p>
                  {distribution.shares.map((s) => (
                    <ShareBar key={s.option} label={s.option} value={`${s.percent}%`} fraction={s.percent / 100} />
                  ))}
                </div>
              ))}
            {segments && <SegmentsTable segments={segments} minGroupSize={minGroupSize} />}
          </CardBody>
        </Card>
      )}
    </div>
  );
}

function SegmentsTable({ segments, minGroupSize }: { segments: InsightSegments; minGroupSize: number }) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <caption className="mb-2 text-left text-xs text-[var(--color-text-secondary)]">
          Бүлэг бүрээр (хувь)
        </caption>
        <thead>
          <tr className="border-b border-[var(--color-divider)] text-left text-xs text-[var(--color-text-secondary)]">
            <th className="py-2 pr-3 font-medium">Бүлэг</th>
            <th className="py-2 pr-3 font-medium">Хүн</th>
            {segments.options.map((o) => (
              <th key={o} className="py-2 pr-3 font-medium">
                {o}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {segments.rows.map((r) => (
            <tr key={`${r.dimension}-${r.label}`} className="border-b border-[var(--color-divider)]">
              <td className="py-2 pr-3">
                <span className="text-[var(--color-text-secondary)]">{r.dimension} · </span>
                {r.label}
              </td>
              <td className="py-2 pr-3 tabular-nums">{peopleLabel(r.people, minGroupSize)}</td>
              {r.suppressed
                ? segments.options.map((o) => (
                    <td key={o} className="py-2 pr-3 text-[var(--color-text-tertiary)]">
                      —
                    </td>
                  ))
                : r.shares.map((s) => (
                    <td key={s.option} className="py-2 pr-3 tabular-nums">
                      {s.percent}%
                    </td>
                  ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
