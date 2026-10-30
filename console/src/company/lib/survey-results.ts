import { MIN_SEGMENT_SAMPLE, genderLabel, share } from "./analytics";
import type { AnalyticsSlice, QuestionBreakdown, QuestionType, SegmentBreakdown } from "./api";

/**
 * How one survey's answers are shown: per question the answer distribution and "who answered what" by gender
 * and age band. The backend already hides every group too small to stay anonymous; this module only orders,
 * measures and explains what it sent.
 */

/** Said wherever groups were left out because they had too few people. */
export const HIDDEN_GROUPS_NOTE = `${MIN_SEGMENT_SAMPLE}-аас цөөн хүнтэй бүлгийг нууцлалын үүднээс харуулахгүй.`;

/** Said instead of a free-text question's answers. */
export const TEXT_ANSWERS_PRIVATE = "Бичгээр өгсөн хариултыг хариулагчдын нууцлалын үүднээс харуулахгүй.";

/** How a cross-table cell is read. */
export const SEGMENT_LEGEND =
  "Нүд бүр тухайн бүлгийн хариулсан хүмүүсийн хэдэн хувь нь энэ хариултыг сонгосныг харуулна. Өнгө тод байх тусам хувь өндөр.";

/** Added when one person may pick several answers. */
export const MULTI_CHOICE_NOTE = "Олон хариулт сонгох боломжтой тул нийлбэр нь 100%-аас их байж болно.";

const TYPE_LABEL: Record<QuestionType, string> = {
  SINGLE_CHOICE: "Нэг сонголттой",
  MULTI_CHOICE: "Олон сонголттой",
  RATING: "Үнэлгээ",
  TEXT: "Чөлөөт хариулт",
};

/** The question type as the company reads it. */
export function questionTypeLabel(type: QuestionType): string {
  return TYPE_LABEL[type] ?? type;
}

/** What a question's section shows. */
export type QuestionView = "text" | "unanswered" | "withheld" | "shown";

export function questionView(q: Pick<QuestionBreakdown, "type" | "answered" | "options">): QuestionView {
  if (q.type === "TEXT") return "text";
  if (q.answered === 0) return "unanswered";
  if (q.answered < MIN_SEGMENT_SAMPLE || q.options.length === 0) return "withheld";
  return "shown";
}

/**
 * The answers in reading order. A rating keeps its scale (Маш муу … Маш сайн, or the older three stops) exactly
 * as the backend stores it; choice answers are ranked by count, ties keeping their survey order.
 */
export function orderedOptions(q: Pick<QuestionBreakdown, "type" | "options">): AnalyticsSlice[] {
  if (q.type === "RATING") return [...q.options];
  return q.options
    .map((option, index) => ({ option, index }))
    .sort((a, b) => b.option.count - a.option.count || a.index - b.index)
    .map(({ option }) => option);
}

/** True for "MALE" / "FEMALE"; every other segment is an age band. */
export function isGenderSegment(label: string): boolean {
  return label === "MALE" || label === "FEMALE";
}

export interface SegmentColumn {
  label: string;
  /** How many of the group answered the question. */
  size: number;
}

export interface SegmentGroup {
  title: string;
  columns: SegmentColumn[];
}

export interface SegmentCell {
  segment: string;
  count: number;
  /** Share of the group (whole number, 0..100). */
  percent: number;
}

export interface SegmentRow {
  option: string;
  cells: SegmentCell[];
}

export interface SegmentGrid {
  groups: SegmentGroup[];
  rows: SegmentRow[];
}

/**
 * The cross-table answer × group: columns are grouped as Хүйс then Нас (an empty group is left out), rows follow
 * `optionOrder` (answers the backend did not list are skipped), each cell is the share of that group's answerers.
 */
export function segmentGrid(breakdown: SegmentBreakdown, optionOrder: readonly string[]): SegmentGrid {
  const columns = breakdown.segments.map((s, index) => ({ label: s.label, size: s.count, index }));
  const gender = columns.filter((c) => isGenderSegment(c.label));
  const age = columns.filter((c) => !isGenderSegment(c.label));
  const ordered = [...gender, ...age];
  const groups: SegmentGroup[] = [
    { title: "Хүйс", columns: gender },
    { title: "Нас", columns: age },
  ]
    .filter((g) => g.columns.length > 0)
    .map((g) => ({
      title: g.title,
      columns: g.columns.map(({ label, size }) => ({ label: genderLabel(label), size })),
    }));

  const byLabel = new Map(breakdown.options.map((o) => [o.label, o.counts]));
  const rows = optionOrder
    .filter((option) => byLabel.has(option))
    .map((option) => {
      const counts = byLabel.get(option)!;
      return {
        option,
        cells: ordered.map((c) => {
          const count = counts[c.index] ?? 0;
          return { segment: genderLabel(c.label), count, percent: share(count, c.size) };
        }),
      };
    });
  return { groups, rows };
}

/**
 * Whether some answerers are missing from the cross-table because their group was too small (or could be worked
 * out from the others). Every viewer has a gender and a birth date, so the shown genders, and separately the shown
 * age bands, add up to everyone who answered unless something was hidden.
 */
export function hasHiddenGroups(
  q: Pick<QuestionBreakdown, "type" | "answered">,
  breakdown: SegmentBreakdown | undefined,
): boolean {
  if (q.type === "TEXT" || q.answered === 0) return false;
  if (!breakdown) return true;
  const sum = (gender: boolean) =>
    breakdown.segments.filter((s) => isGenderSegment(s.label) === gender).reduce((a, s) => a + s.count, 0);
  return sum(true) < q.answered || sum(false) < q.answered;
}

/** One question with the pieces its section needs. */
export interface QuestionResult {
  question: QuestionBreakdown;
  view: QuestionView;
  options: AnalyticsSlice[];
  grid: SegmentGrid | null;
  hiddenGroups: boolean;
}

/** Joins each question with its segment breakdown (matched by id) and orders everything for display. */
export function questionResults(
  questions: readonly QuestionBreakdown[],
  segments: readonly SegmentBreakdown[],
): QuestionResult[] {
  const byQuestion = new Map(segments.map((s) => [s.questionId, s]));
  return questions.map((question) => {
    const view = questionView(question);
    const options = orderedOptions(question);
    const breakdown = byQuestion.get(question.questionId);
    const grid =
      view === "shown" && breakdown
        ? segmentGrid(breakdown, options.map((o) => o.label))
        : null;
    return {
      question,
      view,
      options,
      grid: grid && grid.rows.length > 0 && grid.groups.length > 0 ? grid : null,
      hiddenGroups: view === "shown" && hasHiddenGroups(question, breakdown),
    };
  });
}

/** True when nobody has answered any question yet. */
export function noAnswersYet(questions: readonly Pick<QuestionBreakdown, "answered">[]): boolean {
  return questions.every((q) => q.answered === 0);
}
