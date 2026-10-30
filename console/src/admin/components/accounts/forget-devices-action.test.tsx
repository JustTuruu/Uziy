import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { adminApi, ApiError } from "@/lib/api";
import { FORGET_DEVICES_COPY, ForgetDevicesAction } from "./forget-devices-action";

async function openDialog() {
  await userEvent.click(screen.getByRole("button", { name: FORGET_DEVICES_COPY.action }));
  return screen.getByRole("alertdialog", { name: FORGET_DEVICES_COPY.title });
}

describe("ForgetDevicesAction", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("asks first, naming the company and what will happen", async () => {
    const forget = vi.spyOn(adminApi, "forgetTrustedDevices").mockResolvedValue(null);
    render(<ForgetDevicesAction userId={12} accountName="MobiCom" />);

    const dialog = await openDialog();

    expect(dialog).toHaveTextContent("MobiCom");
    expect(dialog).toHaveTextContent("30 хоног");
    expect(forget).not.toHaveBeenCalled();
  });

  it("forgets the account's browsers once confirmed and says so", async () => {
    const forget = vi.spyOn(adminApi, "forgetTrustedDevices").mockResolvedValue(null);
    render(<ForgetDevicesAction userId={12} accountName="MobiCom" />);

    const dialog = await openDialog();
    await userEvent.click(within(dialog).getByRole("button", { name: FORGET_DEVICES_COPY.confirm }));

    await waitFor(() => expect(screen.getByRole("status")).toHaveTextContent(FORGET_DEVICES_COPY.done));
    expect(forget).toHaveBeenCalledWith(12);
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("does nothing when cancelled", async () => {
    const forget = vi.spyOn(adminApi, "forgetTrustedDevices").mockResolvedValue(null);
    render(<ForgetDevicesAction userId={12} accountName="MobiCom" />);

    const dialog = await openDialog();
    await userEvent.click(within(dialog).getByRole("button", { name: "Болих" }));

    expect(forget).not.toHaveBeenCalled();
    expect(screen.queryByRole("status")).toBeNull();
  });

  it("shows the backend's words when it fails", async () => {
    vi.spyOn(adminApi, "forgetTrustedDevices").mockRejectedValue(
      new ApiError("Хэрэглэгч олдсонгүй", 404, null),
    );
    render(<ForgetDevicesAction userId={12} accountName="MobiCom" />);

    const dialog = await openDialog();
    await userEvent.click(within(dialog).getByRole("button", { name: FORGET_DEVICES_COPY.confirm }));

    await waitFor(() => expect(screen.getByRole("alert")).toHaveTextContent("Хэрэглэгч олдсонгүй"));
  });
});
