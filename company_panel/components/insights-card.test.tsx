import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { InsightsCard } from "./insights-card";

describe("InsightsCard", () => {
  it("lists every finding", () => {
    render(
      <InsightsCard
        insights={[
          { tone: "info", text: "Нэгдүгээр" },
          { tone: "success", text: "Хоёрдугаар" },
          { tone: "warning", text: "Гуравдугаар" },
        ]}
      />,
    );
    expect(screen.getAllByRole("listitem")).toHaveLength(3);
    expect(screen.getByText("Гуравдугаар")).toBeInTheDocument();
  });

  it("renders nothing when there is nothing to say", () => {
    const { container } = render(<InsightsCard insights={[]} />);
    expect(container).toBeEmptyDOMElement();
  });
});
