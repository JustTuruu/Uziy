import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { CampaignImageEditor } from "./campaign-image-editor";
import { adminApi } from "@/lib/api";
vi.mock("@/lib/api", () => ({ adminApi: { uploadImage: vi.fn(), removeImage: vi.fn() }, mediaUrl: (s: string) => `http://localhost:8080${s}` }));
beforeEach(() => {
  vi.clearAllMocks();
  URL.createObjectURL = vi.fn(() => "blob:preview");
  URL.revokeObjectURL = vi.fn();
});
describe("campaign cover", () => {
  it("previews before saving and sends the selected file", async () => {
    const saved = vi.fn(); const user = userEvent.setup();
    vi.mocked(adminApi.uploadImage).mockResolvedValue({ thumbnailUrl: "/public/campaigns/1/image?v=2" });
    render(<CampaignImageEditor campaignId={1} onSaved={saved}/>);
    const file = new File(["png"], "cover.png", { type: "image/png" });
    await user.upload(screen.getByLabelText("Зураг сонгох"), file);
    expect(screen.getByRole("img")).toHaveAttribute("src", "blob:preview");
    expect(adminApi.uploadImage).not.toHaveBeenCalled();
    await user.click(screen.getByRole("button", { name: "Зураг хадгалах" }));
    await waitFor(() => expect(saved).toHaveBeenCalledWith("/public/campaigns/1/image?v=2"));
    expect(adminApi.uploadImage).toHaveBeenCalledWith(1, file);
  });
  it("rejects oversized files without uploading", async () => {
    render(<CampaignImageEditor campaignId={1} onSaved={vi.fn()}/>);
    await userEvent.upload(screen.getByLabelText("Зураг сонгох"), new File([new Uint8Array(5 * 1024 * 1024 + 1)], "large.png", { type: "image/png" }));
    expect(screen.getByRole("alert")).toHaveTextContent("5 MB");
    expect(adminApi.uploadImage).not.toHaveBeenCalled();
  });
  it("keeps the selected preview on failure so saving can be retried", async () => {
    vi.mocked(adminApi.uploadImage).mockRejectedValue(new Error("Холболт тасарлаа"));
    render(<CampaignImageEditor campaignId={1} thumbnailUrl="/old" onSaved={vi.fn()}/>);
    await userEvent.upload(screen.getByLabelText("Зураг сонгох"), new File(["png"], "cover.png", { type: "image/png" }));
    await userEvent.click(screen.getByRole("button", { name: "Зураг хадгалах" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Холболт тасарлаа");
    expect(screen.getByRole("img")).toHaveAttribute("src", "blob:preview");
    expect(screen.getByRole("button", { name: "Зураг хадгалах" })).toBeEnabled();
  });
  it("removes the saved cover", async () => {
    const saved = vi.fn();
    vi.mocked(adminApi.removeImage).mockResolvedValue({ thumbnailUrl: null });
    render(<CampaignImageEditor campaignId={1} thumbnailUrl="/old" onSaved={saved}/>);
    await userEvent.click(screen.getByRole("button", { name: "Зураг арилгах" }));
    await waitFor(() => expect(saved).toHaveBeenCalledWith(null));
  });
});
