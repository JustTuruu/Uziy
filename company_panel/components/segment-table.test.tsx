import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { SegmentBreakdown } from "@/lib/api";
import { SegmentTable } from "./segment-table";

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

describe("SegmentTable", () => {
  it("heads each column with the segment and how many answered", () => {
    render(<SegmentTable breakdown={breakdown} />);
    const table = screen.getByRole("table", { name: "Таалагдсан уу?" });
    const head = within(table).getAllByRole("columnheader");
    expect(head[1]).toHaveTextContent("Эрэгтэй");
    expect(head[1]).toHaveTextContent("(5)");
    expect(head[2]).toHaveTextContent("Эмэгтэй");
    expect(head[3]).toHaveTextContent("18–24");
  });

  it("writes each cell as the share of its segment who chose the option", () => {
    render(<SegmentTable breakdown={breakdown} />);
    const yes = screen.getByRole("row", { name: /Тийм/ });
    expect(yes).toHaveTextContent("100%"); // 5 of 5 men
    expect(yes).toHaveTextContent("20%"); // 2 of 10 women
    expect(yes).toHaveTextContent("47%"); // 7 of 15
  });

  it("labels each row by its option", () => {
    render(<SegmentTable breakdown={breakdown} />);
    expect(screen.getByRole("rowheader", { name: "Үгүй" })).toBeInTheDocument();
  });
});
