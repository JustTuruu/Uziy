import { useId, type ReactNode } from "react";
import { Lock, MessageSquareDashed, RotateCw } from "lucide-react";
import { Badge, Button } from "@uziy/ui";
import { DistributionBars } from "@/components/distribution-bars";
import { SegmentTable, SegmentTintScale } from "@/components/segment-table";
import { TOO_FEW_ANSWERS } from "@/lib/analytics";
import type { QuestionBreakdown, SegmentBreakdown } from "@/lib/api";
import {
  HIDDEN_GROUPS_NOTE,
  MULTI_CHOICE_NOTE,
  SEGMENT_LEGEND,
  TEXT_ANSWERS_PRIVATE,
  noAnswersYet,
  questionResults,
  questionTypeLabel,
  type QuestionResult,
} from "@/lib/survey-results";
import { formatNumber } from "@/lib/utils";

export const NO_QUESTIONS = "Энэ судалгаанд асуулт алга.";
export const NO_ANSWERS_YET = "Хариулт хараахан ирээгүй байна. Үзэгчид хариулж эхэлмэгц энд харагдана.";
export const NO_ANSWERS_TO_QUESTION = "Энэ асуултад хараахан хариулт ирээгүй.";
export const BREAKDOWN_TITLE = "Хэн юу гэж хариулсан";
export const ALL_GROUPS_HIDDEN = `Бүлэг тус бүрээр харуулахад хариулт хүрэлцэхгүй байна. ${HIDDEN_GROUPS_NOTE}`;
export const LOADING_RESULTS = "Хариултуудыг ачаалж байна...";
export const RETRY_LABEL = "Дахин оролдох";
/** Question results are never cut by the analytics window: they always cover the survey's whole life. */
export const RESULTS_WHOLE_LIFE = "Судалгаа эхэлснээс хойшхи бүх хариулт";

/**
 * One survey's results, question by question: the answer distribution as bars, then "who answered what" by
 * gender and age band. Shared by the analytics page and the campaign page, so both always read the same.
 */
export function SurveyResults({
  questions,
  segments,
}: {
  questions: readonly QuestionBreakdown[];
  segments: readonly SegmentBreakdown[];
}) {
  if (questions.length === 0) return <Quiet>{NO_QUESTIONS}</Quiet>;
  if (noAnswersYet(questions)) {
    return (
      <Quiet>
        <MessageSquareDashed size={20} className="mx-auto mb-2 text-[var(--color-text-muted)]" aria-hidden />
        {NO_ANSWERS_YET}
      </Quiet>
    );
  }
  return (
    <ol className="divide-y divide-[var(--color-divider)]">
      {questionResults(questions, segments).map((result, i) => (
        <li key={result.question.questionId} className="py-6 first:pt-0 last:pb-0">
          <QuestionSection number={i + 1} result={result} />
        </li>
      ))}
    </ol>
  );
}

function QuestionSection({ number, result }: { number: number; result: QuestionResult }) {
  const headingId = useId();
  const { question: q, view, options, grid, hiddenGroups } = result;
  return (
    <article aria-labelledby={headingId} className="@container">
      <div className="mb-4 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[var(--color-text-muted)]">
        <span className="font-semibold uppercase tracking-wider">Асуулт {number}</span>
        <Badge>{questionTypeLabel(q.type)}</Badge>
        <span className="font-mono tabular-nums">{formatNumber(q.answered)} хүн хариулсан</span>
      </div>
      <h3 id={headingId} className="mb-4 text-sm font-semibold text-[var(--color-text-primary)]">
        {q.prompt}
      </h3>

      {view === "text" && (
        <Note>
          <Lock size={14} className="mt-0.5 shrink-0" aria-hidden />
          {TEXT_ANSWERS_PRIVATE}
        </Note>
      )}
      {view === "unanswered" && <Note>{NO_ANSWERS_TO_QUESTION}</Note>}
      {view === "withheld" && <Note>{TOO_FEW_ANSWERS}</Note>}

      {view === "shown" && (
        <div className="grid grid-cols-1 gap-8 @3xl:grid-cols-[minmax(0,2fr)_minmax(0,3fr)]">
          <div>
            <DistributionBars title={q.prompt} showTitle={false} slices={options} total={q.answered} scale="share" />
            {q.type === "MULTI_CHOICE" && (
              <p className="mt-3 text-xs text-[var(--color-text-muted)]">{MULTI_CHOICE_NOTE}</p>
            )}
          </div>
          <div>
            <h4 className="mb-3 text-xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
              {BREAKDOWN_TITLE}
            </h4>
            {grid ? (
              <>
                <SegmentTable grid={grid} caption={`${q.prompt} — ${BREAKDOWN_TITLE.toLowerCase()}`} />
                <div className="mt-3 flex flex-wrap items-start justify-between gap-3">
                  <p className="max-w-prose text-xs text-[var(--color-text-muted)]">
                    {SEGMENT_LEGEND}
                    {hiddenGroups && ` ${HIDDEN_GROUPS_NOTE}`}
                  </p>
                  <SegmentTintScale />
                </div>
              </>
            ) : (
              <Note>{ALL_GROUPS_HIDDEN}</Note>
            )}
          </div>
        </div>
      )}
    </article>
  );
}

function Note({ children }: { children: ReactNode }) {
  return <p className="flex items-start gap-2 text-sm text-[var(--color-text-muted)]">{children}</p>;
}

function Quiet({ children }: { children: ReactNode }) {
  return <div className="py-10 text-center text-sm text-[var(--color-text-muted)]">{children}</div>;
}

/** Placeholder rows in the shape of a question section while results load. */
export function SurveyResultsSkeleton() {
  return (
    <div role="status" aria-label={LOADING_RESULTS} className="space-y-8">
      {[0, 1].map((i) => (
        <div key={i} aria-hidden className="animate-pulse space-y-3">
          <div className="h-3 w-40 rounded bg-[var(--color-surface-elevated)]" />
          <div className="h-4 w-2/3 rounded bg-[var(--color-surface-elevated)]" />
          {[80, 55, 30].map((w) => (
            <div key={w} className="space-y-1.5">
              <div className="h-3 w-24 rounded bg-[var(--color-surface-elevated)]" />
              <div className="h-2 rounded-full bg-[var(--color-surface-elevated)]" style={{ width: `${w}%` }} />
            </div>
          ))}
        </div>
      ))}
    </div>
  );
}

/** A failed load, with a way to try again. */
export function SurveyResultsError({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center text-sm">
      <p className="text-[var(--color-danger)]">{message}</p>
      <Button variant="secondary" size="sm" leftIcon={<RotateCw size={14} />} onClick={onRetry}>
        {RETRY_LABEL}
      </Button>
    </div>
  );
}
