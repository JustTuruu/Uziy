"use client";

import { Check, ChevronDown } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import type { KeyboardEvent } from "react";
import { cn } from "./cn";
import { fieldBase, okBorder } from "./input";

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps {
  options: readonly SelectOption[];
  value: string;
  onValueChange: (value: string) => void;
  /** Visible caption above the field. */
  label?: string;
  /** Accessible name when there is no visible [label]. */
  "aria-label"?: string;
  /** Shown while [value] matches no option. */
  placeholder?: string;
  className?: string;
}

/** Index of the option the arrow key lands on; stays inside the list. */
export function stepIndex(current: number, delta: 1 | -1, count: number) {
  return Math.min(count - 1, Math.max(0, current + delta));
}

/**
 * Single-choice dropdown drawn in the design system's colours — the browser's
 * own `<select>` list ignores the theme.
 *
 * Pattern: select-only combobox (WAI-ARIA) — focus stays on the trigger, the
 * highlighted option is announced through `aria-activedescendant`.
 */
export function Select({
  options,
  value,
  onValueChange,
  label,
  placeholder = "Сонгох",
  className,
  ...rest
}: SelectProps) {
  const id = useId();
  const listId = `${id}-list`;
  const labelId = `${id}-label`;
  const rootRef = useRef<HTMLDivElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const [open, setOpen] = useState(false);
  const selectedIndex = options.findIndex((o) => o.value === value);
  const [activeIndex, setActiveIndex] = useState(selectedIndex);

  useEffect(() => {
    if (!open) return;
    const closeOnOutsidePress = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("pointerdown", closeOnOutsidePress);
    return () => document.removeEventListener("pointerdown", closeOnOutsidePress);
  }, [open]);

  useEffect(() => {
    if (open) listRef.current?.children[activeIndex]?.scrollIntoView?.({ block: "nearest" });
  }, [open, activeIndex]);

  const openList = () => {
    setActiveIndex(Math.max(0, selectedIndex));
    setOpen(true);
  };

  const choose = (index: number) => {
    const option = options[index];
    if (option) onValueChange(option.value);
    setOpen(false);
  };

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key === "Escape") {
      if (open) {
        e.preventDefault();
        setOpen(false);
      }
      return;
    }
    if (e.key === "Tab") {
      setOpen(false);
      return;
    }
    const isStep = e.key === "ArrowDown" || e.key === "ArrowUp";
    const isJump = e.key === "Home" || e.key === "End";
    const isChoose = e.key === "Enter" || e.key === " ";
    if (!isStep && !isJump && !isChoose) return;
    e.preventDefault();
    if (!open) {
      openList();
      return;
    }
    if (isChoose) choose(activeIndex);
    else if (e.key === "Home") setActiveIndex(0);
    else if (e.key === "End") setActiveIndex(options.length - 1);
    else
      setActiveIndex((i) =>
        stepIndex(i, e.key === "ArrowDown" ? 1 : -1, options.length),
      );
  };

  return (
    <div ref={rootRef} className="relative block">
      {label && (
        <div
          id={labelId}
          className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]"
        >
          {label}
        </div>
      )}
      <button
        type="button"
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        aria-labelledby={label ? labelId : undefined}
        aria-label={label ? undefined : rest["aria-label"]}
        aria-activedescendant={open ? `${id}-opt-${activeIndex}` : undefined}
        onClick={() => (open ? setOpen(false) : openList())}
        onKeyDown={onKeyDown}
        className={cn(
          fieldBase,
          okBorder,
          "flex min-w-[12rem] cursor-pointer items-center justify-between gap-3 text-left",
          open &&
            "border-[var(--color-primary)] ring-4 ring-[color-mix(in_oklab,var(--color-primary)_14%,transparent)]",
          className,
        )}
      >
        <span
          className={cn(
            "truncate",
            selectedIndex < 0 && "text-[var(--color-text-muted)]",
          )}
        >
          {options[selectedIndex]?.label ?? placeholder}
        </span>
        <ChevronDown
          size={16}
          aria-hidden
          className={cn(
            "shrink-0 text-[var(--color-text-muted)] transition-transform",
            open && "rotate-180 text-[var(--color-primary)]",
          )}
        />
      </button>
      {open && (
        <ul
          ref={listRef}
          id={listId}
          role="listbox"
          aria-labelledby={label ? labelId : undefined}
          aria-label={label ? undefined : rest["aria-label"]}
          className="absolute left-0 z-30 mt-1.5 max-h-64 w-max min-w-full max-w-[min(28rem,90vw)] overflow-auto rounded-xl border border-[var(--color-border-strong)] bg-[var(--color-surface-elevated)] p-1 shadow-[0_16px_40px_rgb(0_0_0/0.55)]"
        >
          {options.map((option, index) => {
            const selected = index === selectedIndex;
            return (
              <li
                key={option.value}
                id={`${id}-opt-${index}`}
                role="option"
                aria-selected={selected}
                // Keep focus on the trigger so the keyboard keeps working.
                onMouseDown={(e) => e.preventDefault()}
                onMouseEnter={() => setActiveIndex(index)}
                onClick={() => choose(index)}
                className={cn(
                  "flex cursor-pointer items-center justify-between gap-6 rounded-lg px-3 py-2 text-[13px]",
                  index === activeIndex &&
                    "bg-[var(--color-surface-hover)]",
                  selected
                    ? "font-semibold text-[var(--color-primary)]"
                    : "text-[var(--color-text-primary)]",
                )}
              >
                <span className="truncate">{option.label}</span>
                {selected && <Check size={15} aria-hidden className="shrink-0" />}
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
