import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import { NumericInput } from "./input";

function Controlled({ initial = "" }: { initial?: string }) {
  const [v, setV] = useState(initial);
  return <NumericInput label="Нас" value={v} onValueChange={setV} />;
}

describe("<NumericInput>", () => {
  it("can be cleared completely without a 0 appearing", async () => {
    render(<Controlled initial="18" />);
    const input = screen.getByRole("textbox");
    await userEvent.clear(input);
    expect(input).toHaveValue("");
  });

  it("does not put a 0 in front when typing after clearing", async () => {
    render(<Controlled initial="1000000" />);
    const input = screen.getByRole("textbox");
    await userEvent.clear(input);
    await userEvent.type(input, "25");
    expect(input).toHaveValue("25");
  });

  it("strips leading zeros the user types", async () => {
    render(<Controlled />);
    const input = screen.getByRole("textbox");
    await userEvent.type(input, "007");
    expect(input).toHaveValue("7");
  });

  it("ignores non-digit keystrokes", async () => {
    render(<Controlled />);
    const input = screen.getByRole("textbox");
    await userEvent.type(input, "1a-2.3e");
    expect(input).toHaveValue("123");
  });

  it("reports sanitized text to onValueChange", async () => {
    const onValueChange = vi.fn();
    render(<NumericInput value="" onValueChange={onValueChange} />);
    await userEvent.type(screen.getByRole("textbox"), "0");
    expect(onValueChange).toHaveBeenLastCalledWith("0");
  });

  it("uses a numeric keyboard on mobile", () => {
    render(<NumericInput value="5" onValueChange={() => {}} />);
    expect(screen.getByRole("textbox")).toHaveAttribute("inputmode", "numeric");
  });
});
