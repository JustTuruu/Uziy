import type { QuestionType } from "./api";

/** The answers every RATING question offers, worst to best (set by the backend). */
export const RATING_LABELS = ["Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн"] as const;

/** Choice and quiz questions let the company type their own answers. */
export function takesOptions(type: QuestionType): boolean {
  return type === "SINGLE_CHOICE" || type === "MULTI_CHOICE" || type === "QUIZ";
}

/** The fewest different answers a quiz needs (backend QuizQuestion.MIN_OPTIONS). */
export const QUIZ_MIN_OPTIONS = 2;

/** The backend's words (QuizQuestion), so the wizard and the server say the same. */
export const QUIZ_NEEDS_VIDEO = "Зөв хариулттай асуулт зөвхөн видеотой судалгаанд байна";
export const QUIZ_NEEDS_OPTIONS = `Зөв хариулттай асуултад дор хаяж ${QUIZ_MIN_OPTIONS} өөр хариулт оруулна уу`;
export const QUIZ_NEEDS_CORRECT = "Зөв хариулттай асуултын зөв хариултыг сонгоно уу";

const BASE_TYPE_OPTIONS: { value: QuestionType; label: string }[] = [
  { value: "SINGLE_CHOICE", label: "Ганц сонголт" },
  { value: "MULTI_CHOICE", label: "Олон сонголт" },
  { value: "TEXT", label: "Чөлөөт текст" },
  { value: "RATING", label: `Үнэлгээ (${RATING_LABELS.join(" · ")})` },
];

const QUIZ_TYPE_OPTION = { value: "QUIZ" as const, label: "Зөв хариулттай (видеоны тухай)" };

/** The question types the company may pick; a quiz only for a video campaign. */
export function questionTypeOptions(hasVideo: boolean): { value: QuestionType; label: string }[] {
  return hasVideo ? [...BASE_TYPE_OPTIONS, QUIZ_TYPE_OPTION] : BASE_TYPE_OPTIONS;
}

/**
 * What is wrong with a quiz question, or null — the same rule the backend applies: a video campaign, at least
 * two different non-blank answers, and one of them marked correct.
 */
export function quizError(hasVideo: boolean, options: string[], correctIndex: number | null): string | null {
  if (!hasVideo) return QUIZ_NEEDS_VIDEO;
  const filled = options.filter((o) => o.trim().length > 0);
  if (filled.length < QUIZ_MIN_OPTIONS || new Set(filled).size !== filled.length) return QUIZ_NEEDS_OPTIONS;
  if (correctIndex === null || !options[correctIndex]?.trim()) return QUIZ_NEEDS_CORRECT;
  return null;
}
