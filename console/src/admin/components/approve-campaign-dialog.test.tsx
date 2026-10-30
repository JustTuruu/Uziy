import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { aCampaign } from "@shared/test/fixtures";
import { platformSettingsApi } from "@admin/lib/api";
import { formatTugrik } from "@admin/lib/utils";
import { ApproveCampaignDialog } from "./approve-campaign-dialog";

/** Paid 1,000 ₮ per viewer for 1,000 viewers at its kind's default of 30 %. */
const paid = aCampaign({
  id: 7,
  status: "PENDING",
  costPerView: 1_000,
  targetViewers: 1_000,
  totalBudget: 1_000_000,
  commissionPercent: 30,
  rewardPerUser: 700,
});

const percentField = () => screen.getByLabelText("Энэ судалгааны шимтгэл (%)");
const confirm = () => screen.getByRole("button", { name: "Баталгаажуулах", hidden: true });

beforeEach(() => {
  vi.spyOn(platformSettingsApi, "get").mockResolvedValue({
    commissionPercent: 30,
    surveyCommissionPercent: 20,
    minRewardPerViewer: 100,
    updatedAt: "2026-10-30T00:00:00Z",
  });
});
afterEach(() => vi.restoreAllMocks());

describe("ApproveCampaignDialog", () => {
  it("starts at the campaign's percentage and approves with the one the admin typed", async () => {
    const onApprove = vi.fn();
    render(<ApproveCampaignDialog campaign={paid} busy={false} onApprove={onApprove} onCancel={() => {}} />);

    // Found once: an error under the field becomes part of its label's text.
    const field = percentField();
    expect(field).toHaveValue("30");
    expect(await screen.findByText(formatTugrik(700))).toBeInTheDocument();

    await userEvent.clear(field);
    await userEvent.type(field, "40");
    expect(screen.getByText(formatTugrik(600))).toBeInTheDocument();
    expect(screen.getByText(formatTugrik(400_000))).toBeInTheDocument();

    await userEvent.click(confirm());
    expect(onApprove).toHaveBeenCalledWith(40);
  });

  it("will not approve at a percentage that is not allowed", async () => {
    const onApprove = vi.fn();
    render(<ApproveCampaignDialog campaign={paid} busy={false} onApprove={onApprove} onCancel={() => {}} />);
    await waitFor(() => expect(confirm()).toBeEnabled());
    const field = percentField();

    await userEvent.clear(field);
    await userEvent.type(field, "95");

    expect(screen.getByText(/1–90%/)).toBeInTheDocument();
    expect(confirm()).toBeDisabled();
  });

  it("stays closed without a campaign", () => {
    render(<ApproveCampaignDialog campaign={null} busy={false} onApprove={() => {}} onCancel={() => {}} />);
    expect(screen.queryByLabelText("Энэ судалгааны шимтгэл (%)")).not.toBeInTheDocument();
  });
});
