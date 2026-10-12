import type { QuestionType } from "./api";

/** The three answers every RATING question offers, worst to best (set by the backend). */
export const RATING_LABELS = ["Муу", "Дунд", "Сайн"] as const;

/** Only choice questions let the company type their own answers. */
export function takesOptions(type: QuestionType): boolean {
  return type === "SINGLE_CHOICE" || type === "MULTI_CHOICE";
}
