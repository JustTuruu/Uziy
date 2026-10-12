import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { DistributionBars } from "./distribution-bars";

describe("DistributionBars", () => {
  it("writes each count and its share of the list total", () => {
    render(
      <DistributionBars
        title="Хот"
        slices={[
          { label: "Улаанбаатар", count: 3 },
          { label: "Дархан", count: 1 },
        ]}
      />,
    );
    expect(screen.getByText("Улаанбаатар")).toBeInTheDocument();
    expect(screen.getByText("3 · 75%")).toBeInTheDocument();
    expect(screen.getByText("1 · 25%")).toBeInTheDocument();
  });

  it("measures shares against an explicit total, e.g. a question's answered count", () => {
    render(
      <DistributionBars
        title="q"
        total={4}
        slices={[
          { label: "A", count: 3 },
          { label: "B", count: 3 },
        ]}
      />,
    );
    expect(screen.getAllByText("3 · 75%")).toHaveLength(2);
  });

  it("scales the bars against the largest row", () => {
    const { container } = render(
      <DistributionBars
        title="t"
        slices={[
          { label: "big", count: 4 },
          { label: "half", count: 2 },
        ]}
      />,
    );
    const fills = container.querySelectorAll<HTMLElement>("div.h-2.rounded-full.bg-\\[var\\(--color-primary\\)\\]");
    expect(fills[0].style.width).toBe("100%");
    expect(fills[1].style.width).toBe("50%");
  });

  it("translates labels with formatLabel", () => {
    render(
      <DistributionBars
        title="Хүйс"
        slices={[{ label: "MALE", count: 1 }]}
        formatLabel={(l) => (l === "MALE" ? "Эрэгтэй" : l)}
      />,
    );
    expect(screen.getByText("Эрэгтэй")).toBeInTheDocument();
  });

  it("says so when there is nothing to show", () => {
    render(<DistributionBars title="t" slices={[]} />);
    expect(screen.getByText("Өгөгдөл алга.")).toBeInTheDocument();
  });

  it("is a labelled region", () => {
    render(<DistributionBars title="Нас" slices={[{ label: "18–24", count: 1 }]} />);
    expect(screen.getByRole("region", { name: "Нас" })).toBeInTheDocument();
  });

  it("can leave the heading out and still be named", () => {
    render(<DistributionBars title="Таалагдсан уу?" showTitle={false} slices={[{ label: "Тийм", count: 1 }]} />);
    expect(screen.queryByRole("heading")).not.toBeInTheDocument();
    expect(screen.getByRole("region", { name: "Таалагдсан уу?" })).toBeInTheDocument();
  });
});
