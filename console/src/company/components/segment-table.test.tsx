import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { segmentGrid } from "@company/lib/survey-results";
import type { SegmentBreakdown } from "@company/lib/api";
import { SegmentTable, SegmentTintScale } from "./segment-table";

const breakdown: SegmentBreakdown = {
  questionId: 1,
  prompt: "Таалагдсан уу?",
  segments: [
    { label: "MALE", count: 5 },
    { label: "FEMALE", count: 10 },
    { label: "18–24", count: 15 },
  ],
  options: [
    { label: "Тийм", counts: [5, 2, 7] },
    { label: "Үгүй", counts: [0, 8, 8] },
  ],
};

const grid = segmentGrid(breakdown, ["Үгүй", "Тийм"]);

describe("SegmentTable", () => {
  it("is a captioned table", () => {
    render(<SegmentTable grid={grid} caption="Таалагдсан уу? — хэн юу гэж хариулсан" />);
    expect(screen.getByRole("table", { name: "Таалагдсан уу? — хэн юу гэж хариулсан" })).toBeInTheDocument();
  });

  it("groups the columns under Хүйс and Нас, each headed with its name and size", () => {
    render(<SegmentTable grid={grid} caption="c" />);
    const head = screen.getAllByRole("columnheader");
    expect(head.map((h) => h.textContent)).toEqual(["Хүйс", "Нас", "Эрэгтэй5 хүн", "Эмэгтэй10 хүн", "18–2415 хүн"]);
    expect(head[0]).toHaveAttribute("colspan", "2");
    expect(head[0]).toHaveAttribute("scope", "colgroup");
  });

  it("writes each cell as the share of its group who chose the answer", () => {
    render(<SegmentTable grid={grid} caption="c" />);
    const yes = screen.getByRole("row", { name: /Тийм/ });
    const cells = within(yes).getAllByRole("cell");
    expect(cells.map((c) => c.textContent)).toEqual(["100%", "20%", "47%"]);
    expect(within(cells[1]).getByTitle("2 / 10 хүн")).toBeInTheDocument();
  });

  it("keeps the row order it is given", () => {
    render(<SegmentTable grid={grid} caption="c" />);
    expect(screen.getAllByRole("rowheader").map((r) => r.textContent)).toEqual(["Үгүй", "Тийм"]);
  });
});

describe("SegmentTintScale", () => {
  it("is decoration only", () => {
    const { container } = render(<SegmentTintScale />);
    expect(container.firstElementChild).toHaveAttribute("aria-hidden", "true");
  });
});
