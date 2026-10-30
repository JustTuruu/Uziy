import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import { Button } from "./button";
import {
  CANCEL_LABEL,
  ConfirmDialog,
  trappedFocusTarget,
  type ConfirmDialogInput,
  type ConfirmTone,
} from "./confirm-dialog";

function Harness({
  onConfirm = () => {},
  tone = "danger",
  input,
  busy = false,
}: {
  onConfirm?: (value: string) => void;
  tone?: ConfirmTone;
  input?: ConfirmDialogInput;
  busy?: boolean;
}) {
  const [open, setOpen] = useState(false);
  return (
    <>
      <Button onClick={() => setOpen(true)}>Дуусгах</Button>
      <ConfirmDialog
        open={open}
        title="Судалгааг дуусгах уу?"
        message="Дууссан судалгааг дахин идэвхжүүлэх боломжгүй."
        confirmLabel="Тийм, дуусгах"
        tone={tone}
        input={input}
        busy={busy}
        onConfirm={(v) => {
          onConfirm(v);
          setOpen(false);
        }}
        onCancel={() => setOpen(false)}
      />
    </>
  );
}

const openIt = async () => {
  await userEvent.click(screen.getByRole("button", { name: "Дуусгах" }));
  return screen.getByRole("alertdialog", { name: "Судалгааг дуусгах уу?" });
};

describe("trappedFocusTarget", () => {
  const items = ["a", "b", "c"];

  it("wraps from the last to the first and back", () => {
    expect(trappedFocusTarget(items, "c", false)).toBe("a");
    expect(trappedFocusTarget(items, "a", true)).toBe("c");
  });

  it("leaves a move inside the dialog to the browser", () => {
    expect(trappedFocusTarget(items, "a", false)).toBeNull();
    expect(trappedFocusTarget(items, "b", true)).toBeNull();
  });

  it("pulls focus back in when it is outside", () => {
    expect(trappedFocusTarget(items, "z", false)).toBe("a");
    expect(trappedFocusTarget(items, null, true)).toBe("c");
    expect(trappedFocusTarget([], "a", false)).toBeNull();
  });
});

describe("<ConfirmDialog>", () => {
  it("renders nothing readable while closed", () => {
    render(<Harness />);
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("is a labelled, described modal with the message", async () => {
    render(<Harness />);
    const dialog = await openIt();
    expect(dialog).toHaveAttribute("aria-modal", "true");
    expect(dialog).toHaveAccessibleDescription(
      "Дууссан судалгааг дахин идэвхжүүлэх боломжгүй.",
    );
    expect(
      screen.getByRole("button", { name: CANCEL_LABEL }),
    ).toBeInTheDocument();
  });

  it("puts focus on 'Болих' for a danger action and gives it back when closed", async () => {
    render(<Harness />);
    const opener = screen.getByRole("button", { name: "Дуусгах" });
    await openIt();
    expect(screen.getByRole("button", { name: CANCEL_LABEL })).toHaveFocus();

    await userEvent.click(screen.getByRole("button", { name: CANCEL_LABEL }));
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(opener).toHaveFocus();
  });

  it("puts focus on the action when it is not dangerous", async () => {
    render(<Harness tone="primary" />);
    await openIt();
    expect(screen.getByRole("button", { name: "Тийм, дуусгах" })).toHaveFocus();
  });

  it("confirms with the action button", async () => {
    const onConfirm = vi.fn();
    render(<Harness onConfirm={onConfirm} />);
    await openIt();
    await userEvent.click(
      screen.getByRole("button", { name: "Тийм, дуусгах" }),
    );
    expect(onConfirm).toHaveBeenCalledWith("");
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("Esc cancels without confirming", async () => {
    const onConfirm = vi.fn();
    render(<Harness onConfirm={onConfirm} />);
    await openIt();
    await userEvent.keyboard("{Escape}");
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
    expect(onConfirm).not.toHaveBeenCalled();
  });

  it("a click on the backdrop cancels, a click inside does not", async () => {
    render(<Harness />);
    const dialog = await openIt();
    await userEvent.click(screen.getByText("Судалгааг дуусгах уу?"));
    expect(screen.getByRole("alertdialog")).toBeInTheDocument();
    await userEvent.click(dialog);
    expect(screen.queryByRole("alertdialog")).not.toBeInTheDocument();
  });

  it("keeps Tab inside the dialog", async () => {
    render(<Harness />);
    await openIt();
    const cancel = screen.getByRole("button", { name: CANCEL_LABEL });
    const confirm = screen.getByRole("button", { name: "Тийм, дуусгах" });
    await userEvent.tab();
    expect(confirm).toHaveFocus();
    await userEvent.tab();
    expect(cancel).toHaveFocus();
    await userEvent.tab({ shift: true });
    expect(confirm).toHaveFocus();
  });

  it("asks for a reason, keeps the action disabled until one is typed and passes it trimmed", async () => {
    const onConfirm = vi.fn();
    render(
      <Harness
        onConfirm={onConfirm}
        input={{ label: "Шалтгаан", required: true, maxLength: 500 }}
      />,
    );
    await openIt();
    const field = screen.getByRole("textbox", { name: "Шалтгаан" });
    expect(field).toHaveFocus();
    expect(field).toHaveAttribute("maxlength", "500");
    const confirm = screen.getByRole("button", { name: "Тийм, дуусгах" });
    expect(confirm).toBeDisabled();

    await userEvent.type(field, "   ");
    expect(confirm).toBeDisabled();
    await userEvent.type(field, "Нэр таарахгүй  ");
    await userEvent.click(confirm);
    expect(onConfirm).toHaveBeenCalledWith("Нэр таарахгүй");
  });

  it("starts with an empty field every time it opens", async () => {
    render(<Harness input={{ label: "Шалтгаан" }} />);
    await openIt();
    await userEvent.type(
      screen.getByRole("textbox", { name: "Шалтгаан" }),
      "ноорог",
    );
    await userEvent.click(screen.getByRole("button", { name: CANCEL_LABEL }));
    await openIt();
    expect(screen.getByRole("textbox", { name: "Шалтгаан" })).toHaveValue("");
  });

  it("cannot be dismissed or confirmed while busy", async () => {
    render(<Harness busy />);
    await openIt();
    expect(screen.getByRole("button", { name: CANCEL_LABEL })).toBeDisabled();
    expect(
      screen.getByRole("button", { name: "Тийм, дуусгах" }),
    ).toBeDisabled();
    await userEvent.keyboard("{Escape}");
    expect(screen.getByRole("alertdialog")).toBeInTheDocument();
  });

  it("keeps the confirm button disabled while the caller says so", async () => {
    const onConfirm = vi.fn();
    render(
      <ConfirmDialog
        open
        title="Батлах"
        confirmLabel="Батлах"
        confirmDisabled
        onConfirm={onConfirm}
        onCancel={() => {}}
      />,
    );
    const confirm = screen.getByRole("button", { name: "Батлах", hidden: true });
    expect(confirm).toBeDisabled();
    await userEvent.click(confirm);
    expect(onConfirm).not.toHaveBeenCalled();
  });
});
