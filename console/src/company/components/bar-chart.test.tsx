import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BarChart, PointsTable } from "./bar-chart";

const points = [
  { key: "a", label: "10.05", value: 2 },
  { key: "b", label: "10.06", value: 0 },
  { key: "c", label: "10.07", value: 8 },
];

function chart() {
  return render(<BarChart points={points} ariaLabel="Хариулт" noun="хариулт" />);
}

describe("BarChart", () => {
  it("draws a bar only for slots with a value", () => {
    const { container } = chart();
    expect(container.querySelectorAll("path")).toHaveLength(2);
  });

  it("scales the axis to a round top above the biggest value", () => {
    chart();
    expect(screen.getByText("10")).toBeInTheDocument();
    expect(screen.getByText("0")).toBeInTheDocument();
  });

  it("labels the first and last slot", () => {
    chart();
    expect(screen.getByText("10.05")).toBeInTheDocument();
    expect(screen.getByText("10.07")).toBeInTheDocument();
  });

  it("draws text at its real size, not scaled with the picture", () => {
    chart();
    const label = screen.getByText("10.05");
    expect(label).toHaveAttribute("font-size", "11");
    const svg = screen.getByRole("img");
    expect(svg).toHaveAttribute("height", "220");
    expect(svg).toHaveAttribute("width", "640"); // the fallback until measured
  });

  it("shows the exact value in a tooltip while a bar is hovered", () => {
    chart();
    expect(screen.queryByRole("status")).not.toBeInTheDocument();

    fireEvent.mouseEnter(screen.getByTestId("bar-c"));

    expect(screen.getByRole("status")).toHaveTextContent("10.07");
    expect(screen.getByRole("status")).toHaveTextContent("8 хариулт");

    fireEvent.mouseLeave(screen.getByRole("img"));
    expect(screen.queryByRole("status")).not.toBeInTheDocument();
  });

  it("is reachable by keyboard: focusing a bar shows its tooltip", () => {
    chart();
    fireEvent.focus(screen.getByLabelText("10.05: 2 хариулт"));
    expect(screen.getByRole("status")).toHaveTextContent("2 хариулт");
  });

  it("has an accessible name", () => {
    chart();
    expect(screen.getByRole("img", { name: "Хариулт" })).toBeInTheDocument();
  });

  it("copes with an all-zero series", () => {
    const { container } = render(
      <BarChart points={[{ key: "z", label: "x", value: 0 }]} ariaLabel="z" noun="n" />,
    );
    expect(container.querySelectorAll("path")).toHaveLength(0);
  });

  it("many slots (24 hours) still label only a few so they never collide", () => {
    const hours = Array.from({ length: 24 }, (_, h) => ({
      key: `h${h}`,
      label: `${String(h).padStart(2, "0")}:00`,
      value: h,
    }));
    const { container } = render(<BarChart points={hours} ariaLabel="h" noun="n" />);
    const texts = [...container.querySelectorAll("text")].map((t) => t.textContent);
    expect(texts.filter((t) => /:00$/.test(t ?? ""))).toHaveLength(6);
  });
});

describe("PointsTable", () => {
  it("lists the rows with their values", () => {
    render(<PointsTable points={points} heading="Огноо" valueHeading="Хариулт" />);
    const rows = screen.getAllByRole("row").slice(1);
    expect(rows[0]).toHaveTextContent("10.05");
    expect(rows[2]).toHaveTextContent("8");
  });

  it("can list the newest first", () => {
    render(<PointsTable points={points} heading="Огноо" valueHeading="Хариулт" newestFirst />);
    expect(screen.getAllByRole("row")[1]).toHaveTextContent("10.07");
  });
});
