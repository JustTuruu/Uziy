import { render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TOO_FEW_ANSWERS } from "@company/lib/analytics";
import type { QuestionBreakdown } from "@company/lib/api";
import { MULTI_CHOICE_NOTE, SEGMENT_LEGEND } from "@company/lib/survey-results";
import {
  NO_ANSWERS_TO_QUESTION,
  NO_QUESTIONS,
  SurveyResults,
  SurveyResultsError,
  SurveyResultsSkeleton,
} from "./survey-results";

const multi: QuestionBreakdown = {
  questionId: 1,
  prompt: "Ямар сувгаар сонсов?",
  type: "MULTI_CHOICE",
  answered: 10,
  options: [
    { label: "Фэйсбүүк", count: 7 },
    { label: "Телевиз", count: 6 },
  ],
};

describe("SurveyResults", () => {
  it("says when the survey has no questions", () => {
    render(<SurveyResults questions={[]} segments={[]} />);
    expect(screen.getByText(NO_QUESTIONS)).toBeInTheDocument();
  });

  it("numbers each question and names its type and answer count", () => {
    render(<SurveyResults questions={[multi]} segments={[]} />);
    const article = screen.getByRole("article", { name: "Ямар сувгаар сонсов?" });
    expect(article).toHaveTextContent("Асуулт 1");
    expect(article).toHaveTextContent("Олон сонголттой");
    expect(article).toHaveTextContent("10 хүн хариулсан");
  });

  it("explains that multiple-choice shares can add up to more than 100%", () => {
    render(<SurveyResults questions={[multi]} segments={[]} />);
    expect(screen.getByText("7 · 70%")).toBeInTheDocument();
    expect(screen.getByText(MULTI_CHOICE_NOTE)).toBeInTheDocument();
  });

  it("tells a question nobody answered from one with too few answers", () => {
    render(
      <SurveyResults
        questions={[
          { ...multi, questionId: 2, prompt: "A", answered: 3, options: [] },
          { ...multi, questionId: 3, prompt: "B", answered: 0, options: [] },
        ]}
        segments={[]}
      />,
    );
    expect(within(screen.getByRole("article", { name: "A" })).getByText(TOO_FEW_ANSWERS)).toBeInTheDocument();
    expect(within(screen.getByRole("article", { name: "B" })).getByText(NO_ANSWERS_TO_QUESTION)).toBeInTheDocument();
  });

  it("explains how to read the cross-table", () => {
    render(
      <SurveyResults
        questions={[multi]}
        segments={[
          {
            questionId: 1,
            prompt: multi.prompt,
            segments: [
              { label: "MALE", count: 5 },
              { label: "FEMALE", count: 5 },
              { label: "25–34", count: 10 },
            ],
            options: [
              { label: "Фэйсбүүк", counts: [3, 4, 7] },
              { label: "Телевиз", counts: [3, 3, 6] },
            ],
          },
        ]}
      />,
    );
    expect(screen.getByRole("table")).toBeInTheDocument();
    expect(screen.getByText(new RegExp(SEGMENT_LEGEND.slice(0, 30)))).toBeInTheDocument();
    expect(screen.queryByText(/нууцлалын үүднээс харуулахгүй/)).not.toBeInTheDocument();
  });
});

describe("SurveyResultsSkeleton", () => {
  it("is a named status", () => {
    render(<SurveyResultsSkeleton />);
    expect(screen.getByRole("status", { name: "Хариултуудыг ачаалж байна..." })).toBeInTheDocument();
  });
});

describe("SurveyResultsError", () => {
  it("shows the message and retries", async () => {
    const onRetry = vi.fn();
    render(<SurveyResultsError message="Алдаа гарлаа" onRetry={onRetry} />);
    expect(screen.getByRole("alert")).toHaveTextContent("Алдаа гарлаа");
    await userEvent.click(screen.getByRole("button", { name: "Дахин оролдох" }));
    expect(onRetry).toHaveBeenCalledOnce();
  });
});
