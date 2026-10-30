import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { HandOverNotice } from "./handover-notice";

describe("HandOverNotice", () => {
  it("shows what to hand over and can be dismissed", async () => {
    const onDismiss = vi.fn();
    render(
      <HandOverNotice
        handOver={{ title: "Данс үүслээ", note: "Дахин харагдахгүй", phoneNumber: "88112233", password: "pw" }}
        onDismiss={onDismiss}
      />,
    );
    expect(screen.getByRole("status")).toHaveTextContent("Данс үүслээ");
    expect(screen.getByText("88112233")).toBeTruthy();
    expect(screen.getByTestId("handover-password").textContent).toBe("pw");
    await userEvent.click(screen.getByRole("button", { name: "Ойлголоо" }));
    expect(onDismiss).toHaveBeenCalledOnce();
  });
});
