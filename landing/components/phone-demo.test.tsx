import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it } from "vitest";
import { DEMO } from "@/lib/content";
import { PhoneDemo } from "./phone-demo";

describe("landing survey preview", () => {
  it("requires a choice, confirms the local demo and allows a fresh attempt", async () => {
    const user = userEvent.setup();
    render(<PhoneDemo />);
    expect(screen.getByRole("button", { name: "Санал өгөх" })).toBeDisabled();
    await user.click(screen.getByRole("radio", { name: "Амт, чанар" }));
    await user.click(screen.getByRole("button", { name: "Санал өгөх" }));
    expect(screen.getByRole("status")).toHaveTextContent(
      DEMO.doneText,
    );
    await user.click(screen.getByRole("button", { name: "Дахин турших" }));
    expect(screen.getByRole("radio", { name: "Амт, чанар" })).not.toBeChecked();
    expect(screen.getByRole("button", { name: "Санал өгөх" })).toBeDisabled();
  });
});
