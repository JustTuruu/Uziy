import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { auth, insightsApi, type InsightsOverview } from "@/lib/api";
import InsightsPage from "./page";

const router = { replace: vi.fn(), push: vi.fn(), refresh: vi.fn() };
vi.mock("next/navigation", () => ({ useRouter: () => router }));

const overview: InsightsOverview = {
  minGroupSize: 50,
  viewers: 1200,
  consentingViewers: 840,
  consentPercent: 70,
  byGender: [
    { label: "Эрэгтэй", people: 400 },
    { label: "Эмэгтэй", people: 440 },
  ],
  byAgeBand: [{ label: "13–17", people: null }],
  byCity: [{ label: "Ховд", people: null }],
  reportableQuestions: 9,
};

describe("Statistics page", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
    auth.setToken("admin-token");
    vi.spyOn(insightsApi, "overview").mockResolvedValue(overview);
    vi.spyOn(insightsApi, "questions").mockResolvedValue([]);
    vi.spyOn(insightsApi, "accessLog").mockResolvedValue([
      { id: 1, adminPhone: "99990000", action: "VIEW_OVERVIEW", detail: "", at: "2026-10-14T04:00:00Z" },
    ]);
  });

  it("shows the consenting panel, hidden small groups and the rules", async () => {
    render(<InsightsPage />);

    expect(await screen.findByText("840")).toBeInTheDocument();
    expect(screen.getByText("70%")).toBeInTheDocument();
    expect(screen.getByText("≈ 440 хүн")).toBeInTheDocument();
    expect(screen.getAllByText("< 50").length).toBe(2);
    expect(screen.getByText("Хамгаалалтын дүрэм")).toBeInTheDocument();
  });

  it("loads the access log only when its tab is opened", async () => {
    render(<InsightsPage />);
    await screen.findByText("840");
    expect(insightsApi.accessLog).not.toHaveBeenCalled();

    await userEvent.click(screen.getByRole("radio", { name: "Хандалтын бүртгэл" }));

    await waitFor(() => expect(screen.getByText("Самбар харсан")).toBeInTheDocument());
  });

  it("sends a signed-out admin to login", () => {
    auth.clear();
    render(<InsightsPage />);
    expect(router.replace).toHaveBeenCalledWith("/login");
  });
});
