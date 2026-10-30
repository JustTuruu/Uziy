import { describe, expect, it } from "vitest";
import {
  QUIZ_NEEDS_CORRECT,
  QUIZ_NEEDS_OPTIONS,
  QUIZ_NEEDS_VIDEO,
  RATING_LABELS,
  questionTypeOptions,
  quizError,
  takesOptions,
} from "./survey";

describe("takesOptions", () => {
  it("is true for the choice types and the quiz", () => {
    expect(takesOptions("SINGLE_CHOICE")).toBe(true);
    expect(takesOptions("MULTI_CHOICE")).toBe(true);
    expect(takesOptions("QUIZ")).toBe(true);
  });

  it("is false for text and rating, whose answers are not typed by the company", () => {
    expect(takesOptions("TEXT")).toBe(false);
    expect(takesOptions("RATING")).toBe(false);
  });
});

describe("RATING_LABELS", () => {
  it("runs worst to best", () => {
    expect([...RATING_LABELS]).toEqual(["Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн"]);
  });
});

describe("questionTypeOptions", () => {
  it("offers the quiz only to a video campaign", () => {
    expect(questionTypeOptions(true).map((o) => o.value)).toContain("QUIZ");
    expect(questionTypeOptions(false).map((o) => o.value)).not.toContain("QUIZ");
  });
});

describe("quizError", () => {
  it("accepts two different answers with one marked correct", () => {
    expect(quizError(true, ["Улаан", "Цэнхэр"], 1)).toBeNull();
  });

  it("needs a video", () => {
    expect(quizError(false, ["Улаан", "Цэнхэр"], 1)).toBe(QUIZ_NEEDS_VIDEO);
  });

  it("needs two different non-blank answers", () => {
    expect(quizError(true, ["Улаан", ""], 0)).toBe(QUIZ_NEEDS_OPTIONS);
    expect(quizError(true, ["Улаан", "Улаан"], 0)).toBe(QUIZ_NEEDS_OPTIONS);
  });

  it("needs a correct answer that is filled in", () => {
    expect(quizError(true, ["Улаан", "Цэнхэр"], null)).toBe(QUIZ_NEEDS_CORRECT);
    expect(quizError(true, ["Улаан", "Цэнхэр", ""], 2)).toBe(QUIZ_NEEDS_CORRECT);
  });
});
