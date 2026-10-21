import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { auth, companyApi, type Campaign } from "@/lib/api";
import CampaignsPage from "./page";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));

function campaign(over: Partial<Campaign>): Campaign {
  return {
    id: 1,
    title: "Шинэ 5G багц",
    videoUrl: "",
    durationSeconds: 45,
    hasVideo: true,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "Улаанбаатар",
    totalBudget: 1_000_000,
    remainingBudget: 640_000,
    costPerView: 1000,
    rewardPerUser: 700,
    targetViewers: 1000,
    commissionPercent: 30,
    paidAt: "2026-10-21T00:00:00Z",
    status: "ACTIVE",
    createdAt: "2026-10-21T00:00:00Z",
    thumbnailUrl: null,
    ...over,
  };
}

describe("Campaigns grid on the light console", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.spyOn(auth, "getToken").mockReturnValue("jwt");
  });

  // Regression (2026-10-21): with the white theme the chip on the dark
  // artwork inherited dark text and disappeared.
  it("the length chip on the dark artwork keeps fixed white ink", async () => {
    vi.spyOn(companyApi, "list").mockResolvedValue([campaign({})]);
    render(<CampaignsPage />);

    const chip = await screen.findByText("45s");
    expect(chip.className).toContain("text-white");
    expect(chip.className).toContain("bg-black/55");
  });

  it("the status badge sits on the panel surface, not on the artwork", async () => {
    vi.spyOn(companyApi, "list").mockResolvedValue([campaign({})]);
    render(<CampaignsPage />);

    const badge = await screen.findByText("Идэвхтэй");
    const holder = badge.closest("div.absolute");
    expect(holder?.className).toContain("bg-[var(--color-surface)]");
  });
});
