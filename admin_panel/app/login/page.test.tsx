import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import LoginPage from "./page";

const handoff = vi.hoisted(() => ({ leaveFor: vi.fn() }));
vi.mock("@/lib/handoff", async (importOriginal) => ({
  ...(await importOriginal<typeof import("@/lib/handoff")>()),
  leaveFor: handoff.leaveFor,
}));

describe("Admin /login", () => {
  it("has no sign-in form and sends the visitor to the one login page", async () => {
    const { SIGN_IN_URL } = await import("@/lib/handoff");
    render(<LoginPage />);

    expect(screen.queryByLabelText("Нууц үг")).toBeNull();
    expect(screen.queryByText(/Админ/)).toBeNull();
    expect(handoff.leaveFor).toHaveBeenCalledWith(SIGN_IN_URL);
    expect(screen.getByRole("link")).toHaveAttribute("href", SIGN_IN_URL);
  });
});
