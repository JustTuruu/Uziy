import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { SegmentedControl } from "./segmented-control";

const options = [
  { value: "A", label: "Бүгд" },
  { value: "B", label: "Эрэгтэй" },
] as const;

describe("<SegmentedControl>", () => {
  it("marks only the current value as checked", () => {
    render(
      <SegmentedControl label="Хүйс" options={options} value="B" onChange={() => {}} />,
    );
    expect(screen.getByRole("radiogroup", { name: "Хүйс" })).toBeInTheDocument();
    expect(screen.getByRole("radio", { name: "Эрэгтэй" })).toBeChecked();
    expect(screen.getByRole("radio", { name: "Бүгд" })).not.toBeChecked();
  });

  it("reports the clicked value", async () => {
    const onChange = vi.fn();
    render(<SegmentedControl options={options} value="A" onChange={onChange} />);
    await userEvent.click(screen.getByRole("radio", { name: "Эрэгтэй" }));
    expect(onChange).toHaveBeenCalledWith("B");
  });
});
