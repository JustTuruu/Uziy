import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import {
  COVER_IMAGE_INVALID,
  COVER_IMAGE_MAX_BYTES,
  ImageUploadCard,
  coverImageError,
} from "./image-upload-card";

const png = () => new File(["png"], "cover.png", { type: "image/png" });

beforeEach(() => {
  URL.createObjectURL = vi.fn(() => "blob:preview");
  URL.revokeObjectURL = vi.fn();
});

describe("coverImageError", () => {
  it("accepts a JPG or PNG up to 5 MB", () => {
    expect(coverImageError(png())).toBeNull();
    expect(
      coverImageError(new File(["x"], "a.jpg", { type: "image/jpeg" })),
    ).toBeNull();
  });

  it("refuses other types, empty and oversized files", () => {
    expect(coverImageError(new File(["x"], "a.gif", { type: "image/gif" }))).toBe(
      COVER_IMAGE_INVALID,
    );
    expect(coverImageError(new File([], "e.png", { type: "image/png" }))).toBe(
      COVER_IMAGE_INVALID,
    );
    expect(
      coverImageError(
        new File([new Uint8Array(COVER_IMAGE_MAX_BYTES + 1)], "big.png", {
          type: "image/png",
        }),
      ),
    ).toBe(COVER_IMAGE_INVALID);
  });
});

describe("<ImageUploadCard>", () => {
  it("previews first and uploads only on save", async () => {
    const onUpload = vi.fn().mockResolvedValue(undefined);
    render(
      <ImageUploadCard inputId="c1" onUpload={onUpload} onRemove={vi.fn()} />,
    );
    const file = png();
    await userEvent.upload(screen.getByLabelText("Зураг сонгох"), file);
    expect(screen.getByRole("img")).toHaveAttribute("src", "blob:preview");
    expect(onUpload).not.toHaveBeenCalled();

    await userEvent.click(screen.getByRole("button", { name: "Зураг хадгалах" }));
    await waitFor(() => expect(onUpload).toHaveBeenCalledWith(file));
    expect(await screen.findByRole("status")).toHaveTextContent("хадгаллаа");
  });

  it("keeps the pick after a failed save so it can be retried", async () => {
    const onUpload = vi.fn().mockRejectedValue(new Error("Холболт тасарлаа"));
    render(
      <ImageUploadCard inputId="c1" onUpload={onUpload} onRemove={vi.fn()} />,
    );
    await userEvent.upload(screen.getByLabelText("Зураг сонгох"), png());
    await userEvent.click(screen.getByRole("button", { name: "Зураг хадгалах" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Холболт тасарлаа");
    expect(screen.getByRole("button", { name: "Зураг хадгалах" })).toBeEnabled();
  });

  it("removes a saved cover", async () => {
    const onRemove = vi.fn().mockResolvedValue(undefined);
    render(
      <ImageUploadCard
        inputId="c1"
        imageUrl="http://x/old.png"
        onUpload={vi.fn()}
        onRemove={onRemove}
      />,
    );
    await userEvent.click(screen.getByRole("button", { name: "Зураг арилгах" }));
    await waitFor(() => expect(onRemove).toHaveBeenCalledOnce());
  });

  it("when locked shows the image and the note, with nothing to change", () => {
    render(
      <ImageUploadCard
        inputId="c1"
        imageUrl="http://x/old.png"
        lockedNote="Батлагдсан"
        onUpload={vi.fn()}
        onRemove={vi.fn()}
      />,
    );
    expect(screen.getByRole("img")).toHaveAttribute("src", "http://x/old.png");
    expect(screen.getByText("Батлагдсан")).toBeInTheDocument();
    expect(screen.queryByLabelText("Зураг сонгох")).toBeNull();
    expect(screen.queryByRole("button")).toBeNull();
  });
});
