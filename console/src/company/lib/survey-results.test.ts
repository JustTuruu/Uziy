import { describe, expect, it } from "vitest";
import type { QuestionBreakdown, SegmentBreakdown } from "./api";
import { MIN_SEGMENT_SAMPLE } from "./analytics";
import {
  HIDDEN_GROUPS_NOTE,
  hasHiddenGroups,
  isGenderSegment,
  noAnswersYet,
  orderedOptions,
  questionResults,
  questionTypeLabel,
  questionView,
  segmentGrid,
} from "./survey-results";

function question(over: Partial<QuestionBreakdown> = {}): QuestionBreakdown {
  return {
    questionId: 1,
    prompt: "Таалагдсан уу?",
    type: "SINGLE_CHOICE",
    answered: 20,
    options: [
      { label: "Үгүй", count: 5 },
      { label: "Тийм", count: 12 },
      { label: "Мэдэхгүй", count: 3 },
    ],
    ...over,
  };
}

/** 20 answerers: 8 men + 12 women; 9 aged 18–24 + 11 aged 25–34. */
function breakdown(over: Partial<SegmentBreakdown> = {}): SegmentBreakdown {
  return {
    questionId: 1,
    prompt: "Таалагдсан уу?",
    segments: [
      { label: "MALE", count: 8 },
      { label: "18–24", count: 9 },
      { label: "FEMALE", count: 12 },
      { label: "25–34", count: 11 },
    ],
    options: [
      { label: "Үгүй", counts: [4, 1, 1, 4] },
      { label: "Тийм", counts: [2, 7, 10, 5] },
      { label: "Мэдэхгүй", counts: [2, 1, 1, 2] },
    ],
    ...over,
  };
}

describe("HIDDEN_GROUPS_NOTE", () => {
  it("names the minimum", () => {
    expect(HIDDEN_GROUPS_NOTE).toBe(`${MIN_SEGMENT_SAMPLE}-аас цөөн хүнтэй бүлгийг нууцлалын үүднээс харуулахгүй.`);
  });
});

describe("questionTypeLabel", () => {
  it.each([
    ["SINGLE_CHOICE", "Нэг сонголттой"],
    ["MULTI_CHOICE", "Олон сонголттой"],
    ["RATING", "Үнэлгээ"],
    ["TEXT", "Чөлөөт хариулт"],
  ] as const)("%s → %s", (type, label) => {
    expect(questionTypeLabel(type)).toBe(label);
  });
});

describe("questionView", () => {
  it("never shows free text", () => {
    expect(questionView(question({ type: "TEXT", options: [] }))).toBe("text");
  });

  it("tells an unanswered question from a withheld one", () => {
    expect(questionView(question({ answered: 0, options: [] }))).toBe("unanswered");
    expect(questionView(question({ answered: MIN_SEGMENT_SAMPLE - 1, options: [] }))).toBe("withheld");
  });

  it("shows a question answered by at least the minimum", () => {
    expect(questionView(question({ answered: MIN_SEGMENT_SAMPLE }))).toBe("shown");
  });

  it("treats a big-enough question without option counts as withheld", () => {
    expect(questionView(question({ options: [] }))).toBe("withheld");
  });
});

describe("orderedOptions", () => {
  it("ranks choice answers by count", () => {
    expect(orderedOptions(question()).map((o) => o.label)).toEqual(["Тийм", "Үгүй", "Мэдэхгүй"]);
  });

  it("keeps the survey order on a tie", () => {
    const q = question({
      options: [
        { label: "B", count: 2 },
        { label: "A", count: 2 },
        { label: "C", count: 4 },
      ],
    });
    expect(orderedOptions(q).map((o) => o.label)).toEqual(["C", "B", "A"]);
  });

  it("keeps a five-stop rating on its scale", () => {
    const labels = ["Маш муу", "Муу", "Дунд", "Сайн", "Маш сайн"];
    const q = question({
      type: "RATING",
      options: labels.map((label, i) => ({ label, count: [1, 9, 2, 8, 3][i] })),
    });
    expect(orderedOptions(q).map((o) => o.label)).toEqual(labels);
  });

  it("keeps an older three-stop rating on its scale", () => {
    const q = question({
      type: "RATING",
      options: [
        { label: "Муу", count: 1 },
        { label: "Дунд", count: 9 },
        { label: "Сайн", count: 4 },
      ],
    });
    expect(orderedOptions(q).map((o) => o.label)).toEqual(["Муу", "Дунд", "Сайн"]);
  });

  it("does not change the question it was given", () => {
    const q = question();
    orderedOptions(q);
    expect(q.options[0].label).toBe("Үгүй");
  });
});

describe("isGenderSegment", () => {
  it("knows the two genders from age bands", () => {
    expect(isGenderSegment("MALE")).toBe(true);
    expect(isGenderSegment("FEMALE")).toBe(true);
    expect(isGenderSegment("18–24")).toBe(false);
  });
});

describe("segmentGrid", () => {
  it("groups the columns as gender first, then age, with readable names and sizes", () => {
    const grid = segmentGrid(breakdown(), ["Тийм", "Үгүй", "Мэдэхгүй"]);
    expect(grid.groups).toEqual([
      {
        title: "Хүйс",
        columns: [
          { label: "Эрэгтэй", size: 8 },
          { label: "Эмэгтэй", size: 12 },
        ],
      },
      {
        title: "Нас",
        columns: [
          { label: "18–24", size: 9 },
          { label: "25–34", size: 11 },
        ],
      },
    ]);
  });

  it("orders the rows like the bars and keeps every cell under its column", () => {
    const grid = segmentGrid(breakdown(), ["Тийм", "Үгүй", "Мэдэхгүй"]);
    expect(grid.rows.map((r) => r.option)).toEqual(["Тийм", "Үгүй", "Мэдэхгүй"]);
    expect(grid.rows[0].cells).toEqual([
      { segment: "Эрэгтэй", count: 2, percent: 25 },
      { segment: "Эмэгтэй", count: 10, percent: 83 },
      { segment: "18–24", count: 7, percent: 78 },
      { segment: "25–34", count: 5, percent: 45 },
    ]);
  });

  it("takes each percent of its own group, not of everyone", () => {
    const grid = segmentGrid(breakdown(), ["Үгүй"]);
    expect(grid.rows[0].cells.map((c) => c.percent)).toEqual([50, 8, 11, 36]);
  });

  it("leaves out an empty dimension and options the backend did not list", () => {
    const grid = segmentGrid(
      breakdown({
        segments: [{ label: "FEMALE", count: 12 }],
        options: [{ label: "Тийм", counts: [10] }],
      }),
      ["Тийм", "Байхгүй"],
    );
    expect(grid.groups.map((g) => g.title)).toEqual(["Хүйс"]);
    expect(grid.rows.map((r) => r.option)).toEqual(["Тийм"]);
  });
});

describe("hasHiddenGroups", () => {
  it("is false when the shown genders and the shown ages each add up to everyone", () => {
    expect(hasHiddenGroups(question(), breakdown())).toBe(false);
  });

  it("is true when an age band was left out", () => {
    const b = breakdown({
      segments: [
        { label: "MALE", count: 8 },
        { label: "FEMALE", count: 12 },
        { label: "25–34", count: 16 },
      ],
    });
    expect(hasHiddenGroups(question(), b)).toBe(true);
  });

  it("is true when a gender was left out", () => {
    const b = breakdown({
      segments: [
        { label: "FEMALE", count: 15 },
        { label: "18–24", count: 9 },
        { label: "25–34", count: 11 },
      ],
    });
    expect(hasHiddenGroups(question(), b)).toBe(true);
  });

  it("is true when every group was too small to send", () => {
    expect(hasHiddenGroups(question(), undefined)).toBe(true);
  });

  it("is false for free text and for a question nobody answered", () => {
    expect(hasHiddenGroups(question({ type: "TEXT" }), undefined)).toBe(false);
    expect(hasHiddenGroups(question({ answered: 0 }), undefined)).toBe(false);
  });
});

describe("questionResults", () => {
  it("joins each question with its own breakdown by id", () => {
    const q2 = question({ questionId: 2, prompt: "Дахин авах уу?" });
    const [first, second] = questionResults([question(), q2], [breakdown()]);
    expect(first.grid?.rows[0].option).toBe("Тийм");
    expect(first.hiddenGroups).toBe(false);
    expect(second.grid).toBeNull();
    expect(second.hiddenGroups).toBe(true);
  });

  it("gives a withheld or text question no table and no hidden-group note", () => {
    const [withheld, text] = questionResults(
      [question({ answered: 3, options: [] }), question({ questionId: 3, type: "TEXT", options: [] })],
      [],
    );
    expect(withheld.view).toBe("withheld");
    expect(withheld.grid).toBeNull();
    expect(withheld.hiddenGroups).toBe(false);
    expect(text.view).toBe("text");
    expect(text.hiddenGroups).toBe(false);
  });
});

describe("noAnswersYet", () => {
  it("is true only while every question is unanswered", () => {
    expect(noAnswersYet([])).toBe(true);
    expect(noAnswersYet([{ answered: 0 }, { answered: 0 }])).toBe(true);
    expect(noAnswersYet([{ answered: 0 }, { answered: 1 }])).toBe(false);
  });
});
