import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { IconButton } from "./icon-button";

describe("<IconButton>", () => {
  it("is named by its label and is not a submit button", () => {
    render(
      <IconButton label="Устгах">
        <svg />
      </IconButton>,
    );
    const btn = screen.getByRole("button", { name: "Устгах" });
    expect(btn).toHaveAttribute("type", "button");
  });

  it("fires onClick", async () => {
    const onClick = vi.fn();
    render(
      <IconButton label="Устгах" onClick={onClick}>
        <svg />
      </IconButton>,
    );
    await userEvent.click(screen.getByRole("button"));
    expect(onClick).toHaveBeenCalledOnce();
  });
});
