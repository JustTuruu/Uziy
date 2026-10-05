import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, auth, platformSettingsApi } from "@/lib/api";
import { formatTugrik } from "@/lib/utils";
import CommissionSettingsPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

const percentField = () => screen.getByLabelText(/Платформын шимтгэл \(%\)/);
const minField = () => screen.getByLabelText(/хамгийн бага урамшуулал/);

beforeEach(() => {
  vi.spyOn(auth, "getToken").mockReturnValue("admin-tok");
  vi.spyOn(platformSettingsApi, "get").mockResolvedValue({
    commissionPercent: 30,
    minRewardPerViewer: 100,
    updatedAt: "2026-09-28T10:00:00Z",
  });
});
afterEach(() => vi.restoreAllMocks());

describe("Admin commission settings page", () => {
  it("loads the current settings and shows the live example", async () => {
    render(<CommissionSettingsPage />);
    expect(await screen.findByDisplayValue("30")).toBe(percentField());
    expect(minField()).toHaveValue("100");
    expect(screen.getByText("Шимтгэл ба урамшуулал")).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(700))).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(300_000))).toBeInTheDocument();
    expect(screen.queryByText(/Судалгааны үнэ/)).not.toBeInTheDocument();
  });

  it("updates the example as the percent is edited", async () => {
    render(<CommissionSettingsPage />);
    await screen.findByDisplayValue("30");
    await userEvent.clear(percentField());
    await userEvent.type(percentField(), "35");
    expect(screen.getByText(formatTugrik(650))).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(350_000))).toBeInTheDocument();
  });

  it("PATCHes valid values", async () => {
    const update = vi.spyOn(adminApi, "updateSettings").mockResolvedValue({
      commissionPercent: 35,
      minRewardPerViewer: 150,
      updatedAt: "2026-09-28T11:00:00Z",
    });
    render(<CommissionSettingsPage />);
    await screen.findByDisplayValue("30");
    await userEvent.clear(percentField());
    await userEvent.type(percentField(), "35");
    await userEvent.clear(minField());
    await userEvent.type(minField(), "150");
    await userEvent.click(screen.getByRole("button", { name: "Хадгалах" }));

    expect(update).toHaveBeenCalledWith({ commissionPercent: 35, minRewardPerViewer: 150 });
    expect(await screen.findByText("Хадгаллаа")).toBeInTheDocument();
  });

  it("rejects an out-of-range commission without calling the API", async () => {
    const update = vi.spyOn(adminApi, "updateSettings");
    render(<CommissionSettingsPage />);
    await screen.findByDisplayValue("30");
    await userEvent.clear(percentField());
    await userEvent.type(percentField(), "95");
    await userEvent.click(screen.getByRole("button", { name: "Хадгалах" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("1–90%");
    expect(update).not.toHaveBeenCalled();
  });
});
