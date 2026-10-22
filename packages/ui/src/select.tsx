"use client";

import { Check, ChevronDown, Search } from "lucide-react";
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
  /**
   * Puts a type-ahead box at the top of the open menu that narrows the options
   * by label — for long lists (e.g. every company's name).
   */
  searchable?: boolean;
  /** Placeholder of the type-ahead box. */
  searchPlaceholder?: string;
  /** Shown in the menu when the typed text matches no option. */
  emptyText?: string;
  className?: string;
}

/** Index of the option the arrow key lands on; stays inside the list. */
export function stepIndex(current: number, delta: 1 | -1, count: number) {
  return Math.min(count - 1, Math.max(0, current + delta));
}

/** Options whose label contains [query], ignoring case and outer spaces. */
export function matchOptions(
  options: readonly SelectOption[],
  query: string,
): readonly SelectOption[] {
  const q = query.trim().toLocaleLowerCase();
  if (!q) return options;
  return options.filter((o) => o.label.toLocaleLowerCase().includes(q));
}

/**
 * Single-choice dropdown drawn in the design system's colours — the browser's
 * own `<select>` list ignores the theme.
 *
 * Pattern: select-only combobox (WAI-ARIA) — focus stays on the trigger, the
 * highlighted option is announced through `aria-activedescendant`. With
 * [searchable] focus moves into the menu's search box instead, which then owns
 * `aria-activedescendant`, and returns to the trigger when the menu closes.
 */
export function Select({
  options,
  value,
  onValueChange,
  label,
  placeholder = "Сонгох",
  searchable = false,
  searchPlaceholder = "Хайх...",
  emptyText = "Олдсонгүй",
  className,
  ...rest
}: SelectProps) {
  const id = useId();
  const listId = `${id}-list`;
  const labelId = `${id}-label`;
  const rootRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const shown = searchable ? matchOptions(options, query) : options;
  const selectedIndex = options.findIndex((o) => o.value === value);
  const [activeIndex, setActiveIndex] = useState(selectedIndex);
  const activeId =
    open && shown[activeIndex] ? `${id}-opt-${activeIndex}` : undefined;

  useEffect(() => {
    if (!open) return;
    const closeOnOutsidePress = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) {
        setOpen(false);
        setQuery("");
      }
    };
    document.addEventListener("pointerdown", closeOnOutsidePress);
    return () => document.removeEventListener("pointerdown", closeOnOutsidePress);
  }, [open]);

  useEffect(() => {
    if (open && searchable) searchRef.current?.focus();
  }, [open, searchable]);

  useEffect(() => {
    if (open) listRef.current?.children[activeIndex]?.scrollIntoView?.({ block: "nearest" });
  }, [open, activeIndex]);

  const openList = () => {
    setQuery("");
    setActiveIndex(Math.max(0, selectedIndex));
    setOpen(true);
  };

  const closeList = ({ refocus = false } = {}) => {
    setOpen(false);
    setQuery("");
    if (refocus && searchable) triggerRef.current?.focus();
  };

  const choose = (index: number) => {
    const option = shown[index];
    if (option) onValueChange(option.value);
    closeList({ refocus: true });
  };

  const step = (key: string) =>
    setActiveIndex((i) =>
      stepIndex(i, key === "ArrowDown" ? 1 : -1, shown.length),
    );

  const onKeyDown = (e: KeyboardEvent<HTMLButtonElement>) => {
    if (e.key === "Escape") {
      if (open) {
        e.preventDefault();
        closeList();
      }
      return;
    }
    if (e.key === "Tab") {
      closeList();
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
    else if (e.key === "End") setActiveIndex(shown.length - 1);
    else step(e.key);
  };

  // In the search box Space, Home and End edit the text, so only the arrows,
  // Enter, Escape and Tab drive the menu.
  const onSearchKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Escape") {
      e.preventDefault();
      closeList({ refocus: true });
    } else if (e.key === "Tab") {
      closeList();
    } else if (e.key === "Enter") {
      e.preventDefault();
      choose(activeIndex);
    } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      step(e.key);
    }
  };

  return (
    <div ref={rootRef} className="relative block">
      {label && (
        <div
          id={labelId}
          className="mb-1.5 text-2xs font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]"
        >
          {label}
        </div>
      )}
      <button
        ref={triggerRef}
        type="button"
        role="combobox"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        aria-labelledby={label ? labelId : undefined}
        aria-label={label ? undefined : rest["aria-label"]}
        aria-activedescendant={searchable ? undefined : activeId}
        onClick={() => (open ? closeList() : openList())}
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
        <div className="absolute left-0 z-30 mt-1.5 w-max min-w-full max-w-[min(28rem,90vw)] rounded-xl border border-[var(--color-border-strong)] bg-[var(--color-surface-elevated)] p-1 shadow-[var(--shadow-popover)]">
          {searchable && (
            <div className="relative mb-1">
              <Search
                size={14}
                aria-hidden
                className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
              />
              <input
                ref={searchRef}
                type="search"
                value={query}
                placeholder={searchPlaceholder}
                aria-label={searchPlaceholder}
                aria-controls={listId}
                aria-activedescendant={activeId}
                autoComplete="off"
                onChange={(e) => {
                  setQuery(e.target.value);
                  setActiveIndex(0);
                }}
                onKeyDown={onSearchKeyDown}
                className={cn(fieldBase, okBorder, "pl-9")}
              />
            </div>
          )}
          <ul
            ref={listRef}
            id={listId}
            role="listbox"
            aria-labelledby={label ? labelId : undefined}
            aria-label={label ? undefined : rest["aria-label"]}
            className="max-h-64 overflow-auto"
          >
            {shown.map((option, index) => {
              const selected = option.value === value;
              return (
                <li
                  key={option.value}
                  id={`${id}-opt-${index}`}
                  role="option"
                  aria-selected={selected}
                  // Keep focus where it is (trigger or search box) so the keyboard keeps working.
                  onMouseDown={(e) => e.preventDefault()}
                  onMouseEnter={() => setActiveIndex(index)}
                  onClick={() => choose(index)}
                  className={cn(
                    "flex cursor-pointer items-center justify-between gap-6 rounded-lg px-3 py-2 text-ui",
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
          {shown.length === 0 && (
            <p
              role="status"
              className="px-3 py-2 text-ui text-[var(--color-text-muted)]"
            >
              {emptyText}
            </p>
          )}
        </div>
      )}
    </div>
  );
}
