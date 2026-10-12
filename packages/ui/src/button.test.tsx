import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { Button, ButtonLink } from "./button";

describe("<Button>", () => {
  it("renders its children", () => {
    render(<Button>Нэвтрэх</Button>);
    expect(screen.getByRole("button", { name: "Нэвтрэх" })).toBeInTheDocument();
  });

  it("fires onClick when clicked", async () => {
    const onClick = vi.fn();
    render(<Button onClick={onClick}>Click</Button>);
    await userEvent.click(screen.getByRole("button"));
    expect(onClick).toHaveBeenCalledOnce();
  });

  it("does not fire onClick when disabled", async () => {
    const onClick = vi.fn();
    render(
      <Button onClick={onClick} disabled>
        Disabled
      </Button>,
    );
    await userEvent.click(screen.getByRole("button"));
    expect(onClick).not.toHaveBeenCalled();
  });

  it("passes through the type attribute", () => {
    render(<Button type="submit">Submit</Button>);
    expect(screen.getByRole("button")).toHaveAttribute("type", "submit");
  });

  it("renders left and right icons", () => {
    render(
      <Button
        leftIcon={<span data-testid="l">L</span>}
        rightIcon={<span data-testid="r">R</span>}
      >
        Save
      </Button>,
    );
    expect(screen.getByTestId("l")).toBeInTheDocument();
    expect(screen.getByTestId("r")).toBeInTheDocument();
  });
});

describe("<ButtonLink>", () => {
  it("renders a real link with the given href", () => {
    render(<ButtonLink href="/login">Нэвтрэх</ButtonLink>);
    expect(screen.getByRole("link", { name: "Нэвтрэх" })).toHaveAttribute(
      "href",
      "/login",
    );
  });

  it("looks like the matching Button variant", () => {
    render(
      <>
        <Button variant="secondary">B</Button>
        <ButtonLink variant="secondary" href="/x">
          L
        </ButtonLink>
      </>,
    );
    expect(screen.getByRole("link").className).toBe(
      screen.getByRole("button").className,
    );
  });

  it("shows icons around the label", () => {
    render(
      <ButtonLink href="/x" leftIcon={<i data-testid="l" />} rightIcon={<i data-testid="r" />}>
        Go
      </ButtonLink>,
    );
    expect(screen.getByTestId("l")).toBeInTheDocument();
    expect(screen.getByTestId("r")).toBeInTheDocument();
  });
});
