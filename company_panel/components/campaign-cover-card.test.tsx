import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { Campaign } from "@/lib/api";
import { companyApi } from "@/lib/api";
import { COVER_LOCKED_NOTE, CampaignCoverCard } from "./campaign-cover-card";

vi.mock("@/lib/api", () => ({
  companyApi: { uploadImage: vi.fn(), removeImage: vi.fn() },
  mediaUrl: (s: string) => `http://localhost:8080${s}`,
}));

function campaign(over: Partial<Campaign> = {}): Campaign {
  return {
    id: 7,
    title: "Судалгаа",
    videoUrl: "",
    durationSeconds: 0,
    hasVideo: false,
    targetGender: "ALL",
    minAge: 18,
    maxAge: 45,
    targetCity: "ALL",
    totalBudget: 100000,
    remainingBudget: 100000,
    costPerView: 705,
    rewardPerUser: 500,
    targetViewers: 141,
    commissionPercent: 29,
    paidAt: null,
    status: "AWAITING_PAYMENT",
    createdAt: "2026-10-14T00:00:00Z",
    thumbnailUrl: null,
    ...over,
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  URL.createObjectURL = vi.fn(() => "blob:preview");
  URL.revokeObjectURL = vi.fn();
});

describe("<CampaignCoverCard>", () => {
  it("uploads the picked cover for the company's own survey", async () => {
    vi.mocked(companyApi.uploadImage).mockResolvedValue({
      thumbnailUrl: "/public/campaigns/7/image?v=1",
    });
    const saved = vi.fn();
    render(<CampaignCoverCard campaign={campaign()} onSaved={saved} />);
    const file = new File(["png"], "cover.png", { type: "image/png" });

    await userEvent.upload(screen.getByLabelText("Зураг сонгох"), file);
    await userEvent.click(screen.getByRole("button", { name: "Зураг хадгалах" }));

    await waitFor(() =>
      expect(saved).toHaveBeenCalledWith("/public/campaigns/7/image?v=1"),
    );
    expect(companyApi.uploadImage).toHaveBeenCalledWith(7, file);
  });

  it("shows the saved cover from the API host and can remove it", async () => {
    vi.mocked(companyApi.removeImage).mockResolvedValue({ thumbnailUrl: null });
    const saved = vi.fn();
    render(
      <CampaignCoverCard
        campaign={campaign({ status: "PENDING", thumbnailUrl: "/public/campaigns/7/image" })}
        onSaved={saved}
      />,
    );
    expect(screen.getByRole("img")).toHaveAttribute(
      "src",
      "http://localhost:8080/public/campaigns/7/image",
    );

    await userEvent.click(screen.getByRole("button", { name: "Зураг арилгах" }));
    await waitFor(() => expect(saved).toHaveBeenCalledWith(null));
    expect(companyApi.removeImage).toHaveBeenCalledWith(7);
  });

  it("after approval the cover is read-only", () => {
    render(
      <CampaignCoverCard
        campaign={campaign({ status: "ACTIVE", thumbnailUrl: "/public/campaigns/7/image" })}
        onSaved={vi.fn()}
      />,
    );
    expect(screen.getByText(COVER_LOCKED_NOTE)).toBeInTheDocument();
    expect(screen.queryByLabelText("Зураг сонгох")).toBeNull();
    expect(screen.queryByRole("button")).toBeNull();
  });
});
