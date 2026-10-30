"use client";

import { CircleHelp, TriangleAlert } from "lucide-react";
import {
  useEffect,
  useId,
  useRef,
  useState,
  type FormEvent,
  type KeyboardEvent,
  type MouseEvent,
  type ReactNode,
} from "react";
import { Button } from "./button";
import { cn } from "./cn";
import { Textarea } from "./input";

export type ConfirmTone = "primary" | "danger";

/** The cancel button's default wording. */
export const CANCEL_LABEL = "Болих";

/** Asks for a short text (e.g. why a request is rejected) before the action is confirmed. */
export interface ConfirmDialogInput {
  label: string;
  placeholder?: string;
  maxLength?: number;
  /** When true, the confirm button stays disabled until something other than spaces is typed. */
  required?: boolean;
}

export interface ConfirmDialogProps {
  open: boolean;
  title: string;
  message?: ReactNode;
  confirmLabel: string;
  cancelLabel?: string;
  /** `danger` for an action that cannot be undone. */
  tone?: ConfirmTone;
  /** While the action runs: both buttons are disabled and the dialog cannot be dismissed. */
  busy?: boolean;
  input?: ConfirmDialogInput;
  /** Keeps the confirm button disabled, e.g. while a value in `message` is invalid. */
  confirmDisabled?: boolean;
  /** Called with the trimmed text of `input` (an empty string when there is none). */
  onConfirm: (value: string) => void;
  onCancel: () => void;
}

const FOCUSABLE =
  'button:not([disabled]), [href], input:not([disabled]), textarea:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * The element Tab (or Shift+Tab) should move to so focus never leaves the dialog, or null when the browser's own
 * move stays inside. Pure, so the trap is tested without a layout engine.
 */
export function trappedFocusTarget<T>(
  focusables: readonly T[],
  active: T | null,
  backwards: boolean,
): T | null {
  if (focusables.length === 0) return null;
  const first = focusables[0];
  const last = focusables[focusables.length - 1];
  const index = active === null ? -1 : focusables.indexOf(active);
  if (index === -1) return backwards ? last : first;
  if (backwards && index === 0) return last;
  if (!backwards && index === focusables.length - 1) return first;
  return null;
}

/**
 * An in-app confirmation, used instead of the browser's `confirm()` / `prompt()`: a modal native `<dialog>`
 * (top layer, the page behind is inert) with a title, a message, an optional text field and two buttons.
 * Esc, the backdrop and 'Болих' cancel; Tab stays inside; focus returns to the control that opened it.
 * Initial focus is on the field, else on the safe choice — 'Болих' for a danger action, the action otherwise.
 */
export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel,
  cancelLabel = CANCEL_LABEL,
  tone = "primary",
  busy = false,
  input,
  confirmDisabled = false,
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  const ref = useRef<HTMLDialogElement>(null);
  const returnFocusTo = useRef<HTMLElement | null>(null);
  const titleId = useId();
  const messageId = useId();

  useEffect(() => {
    const dialog = ref.current;
    if (!dialog) return;
    if (open && !dialog.open) {
      returnFocusTo.current =
        document.activeElement instanceof HTMLElement
          ? document.activeElement
          : null;
      if (typeof dialog.showModal === "function") dialog.showModal();
      else dialog.setAttribute("open", "");
      dialog.querySelector<HTMLElement>("[data-autofocus]")?.focus();
    } else if (!open && dialog.open) {
      dialog.close();
      const back = returnFocusTo.current;
      returnFocusTo.current = null;
      if (back?.isConnected) back.focus();
    }
  }, [open]);

  const cancel = () => {
    if (!busy) onCancel();
  };

  const onKeyDown = (e: KeyboardEvent<HTMLDialogElement>) => {
    if (e.key === "Escape") {
      e.preventDefault();
      cancel();
      return;
    }
    if (e.key !== "Tab") return;
    const focusables = Array.from(
      e.currentTarget.querySelectorAll<HTMLElement>(FOCUSABLE),
    );
    const active =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    const target = trappedFocusTarget(focusables, active, e.shiftKey);
    if (target) {
      e.preventDefault();
      target.focus();
    }
  };

  // A click whose target is the <dialog> itself landed on the backdrop: the content fills the box edge to edge.
  const onClick = (e: MouseEvent<HTMLDialogElement>) => {
    if (e.target === e.currentTarget) cancel();
  };

  return (
    <dialog
      ref={ref}
      role="alertdialog"
      aria-modal="true"
      aria-labelledby={titleId}
      aria-describedby={message ? messageId : undefined}
      onCancel={(e) => {
        e.preventDefault();
        cancel();
      }}
      // Some browsers close a modal on a repeated Esc even when `cancel` is prevented; keep the state in step.
      onClose={() => {
        if (open) onCancel();
      }}
      onKeyDown={onKeyDown}
      onClick={onClick}
      className={cn(
        "m-auto w-[min(28rem,calc(100vw-2rem))] rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] p-0 text-[var(--color-text-primary)] shadow-[var(--shadow-popover)]",
        "backdrop:bg-[color-mix(in_oklab,var(--color-text-primary)_40%,transparent)]",
      )}
    >
      {open && (
        <DialogContent
          title={title}
          titleId={titleId}
          message={message}
          messageId={messageId}
          confirmLabel={confirmLabel}
          cancelLabel={cancelLabel}
          tone={tone}
          busy={busy}
          input={input}
          confirmDisabled={confirmDisabled}
          onConfirm={onConfirm}
          onCancel={cancel}
        />
      )}
    </dialog>
  );
}

/** Mounted only while open, so the typed text starts empty every time the dialog opens. */
function DialogContent({
  title,
  titleId,
  message,
  messageId,
  confirmLabel,
  cancelLabel,
  tone,
  busy,
  input,
  confirmDisabled,
  onConfirm,
  onCancel,
}: Omit<ConfirmDialogProps, "open" | "cancelLabel" | "tone" | "busy"> & {
  titleId: string;
  messageId: string;
  cancelLabel: string;
  tone: ConfirmTone;
  busy: boolean;
}) {
  const [value, setValue] = useState("");
  const trimmed = value.trim();
  const canConfirm = !busy && !confirmDisabled && !(input?.required && trimmed === "");
  const Icon = tone === "danger" ? TriangleAlert : CircleHelp;
  const iconColor =
    tone === "danger" ? "var(--color-danger)" : "var(--color-primary)";

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (canConfirm) onConfirm(trimmed);
  };

  return (
    <form onSubmit={submit} className="p-5">
      <div className="flex items-start gap-3">
        <span
          aria-hidden
          className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full"
          style={{
            backgroundColor: `color-mix(in oklab, ${iconColor} 12%, transparent)`,
            color: iconColor,
          }}
        >
          <Icon size={16} />
        </span>
        <div className="min-w-0 flex-1">
          <h2
            id={titleId}
            className="text-sm font-semibold text-[var(--color-text-primary)]"
          >
            {title}
          </h2>
          {message && (
            <div
              id={messageId}
              className="mt-1 text-ui text-[var(--color-text-secondary)]"
            >
              {message}
            </div>
          )}
          {input && (
            <div className="mt-4">
              <Textarea
                label={input.label}
                placeholder={input.placeholder}
                maxLength={input.maxLength}
                required={input.required}
                value={value}
                onChange={(e) => setValue(e.target.value)}
                disabled={busy}
                data-autofocus
                className="min-h-20"
              />
            </div>
          )}
        </div>
      </div>
      <div className="mt-5 flex flex-wrap justify-end gap-2">
        <Button
          type="button"
          variant="secondary"
          onClick={onCancel}
          disabled={busy}
          data-autofocus={!input && tone === "danger" ? true : undefined}
        >
          {cancelLabel}
        </Button>
        <Button
          type="submit"
          variant={tone === "danger" ? "danger" : "primary"}
          disabled={!canConfirm}
          data-autofocus={!input && tone !== "danger" ? true : undefined}
        >
          {confirmLabel}
        </Button>
      </div>
    </form>
  );
}
