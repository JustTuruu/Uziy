import { cn } from "./cn";
import { sanitizeIntInput } from "./numeric";
import type { InputHTMLAttributes, TextareaHTMLAttributes } from "react";

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  hint?: string;
  error?: string;
}

const fieldBase =
  "w-full rounded-lg border bg-[var(--color-background)] px-3.5 py-2 text-[13px] text-[var(--color-text-primary)] placeholder:text-[var(--color-text-muted)] transition-colors focus:outline-none focus:border-[var(--color-primary)] focus:ring-4 focus:ring-[color-mix(in_oklab,var(--color-primary)_14%,transparent)]";
const okBorder = "border-[var(--color-divider)]";
const errBorder = "border-[var(--color-danger)]";

export function Input({
  label,
  hint,
  error,
  className,
  ...rest
}: InputProps) {
  return (
    <label className="block">
      {label && (
        <div className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
          {label}
        </div>
      )}
      <input
        {...rest}
        className={cn(fieldBase, error ? errBorder : okBorder, className)}
      />
      {(hint || error) && (
        <div
          className={cn(
            "mt-1 text-xs",
            error
              ? "text-[var(--color-danger)]"
              : "text-[var(--color-text-muted)]",
          )}
        >
          {error ?? hint}
        </div>
      )}
    </label>
  );
}

interface NumericInputProps
  extends Omit<InputProps, "type" | "value" | "onChange" | "inputMode"> {
  /** Raw field text (digits only, may be empty). Parse with parseIntInput(). */
  value: string;
  onValueChange: (text: string) => void;
}

/**
 * Whole-number field (money, age, seconds). Deliberately a text input with a
 * numeric keyboard rather than type="number": the value stays a string we
 * control, so the user can clear the field completely without a "0" snapping
 * back, and leading zeros are stripped as they type ("05" → "5").
 */
export function NumericInput({
  value,
  onValueChange,
  ...rest
}: NumericInputProps) {
  return (
    <Input
      {...rest}
      type="text"
      inputMode="numeric"
      pattern="[0-9]*"
      autoComplete="off"
      value={value}
      onChange={(e) => onValueChange(sanitizeIntInput(e.target.value))}
    />
  );
}

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  hint?: string;
  error?: string;
}

export function Textarea({
  label,
  hint,
  error,
  className,
  ...rest
}: TextareaProps) {
  return (
    <label className="block">
      {label && (
        <div className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
          {label}
        </div>
      )}
      <textarea
        {...rest}
        className={cn(
          fieldBase,
          "min-h-24 resize-y",
          error ? errBorder : okBorder,
          className,
        )}
      />
      {(hint || error) && (
        <div
          className={cn(
            "mt-1 text-xs",
            error
              ? "text-[var(--color-danger)]"
              : "text-[var(--color-text-muted)]",
          )}
        >
          {error ?? hint}
        </div>
      )}
    </label>
  );
}

interface SelectProps
  extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
}

export function Select({ label, className, children, ...rest }: SelectProps) {
  return (
    <label className="block">
      {label && (
        <div className="mb-1.5 text-[11px] font-semibold uppercase tracking-wider text-[var(--color-text-secondary)]">
          {label}
        </div>
      )}
      <select
        {...rest}
        className={cn(
          fieldBase,
          okBorder,
          "appearance-none pr-10 [background-image:url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 20 20' fill='none' stroke='%239ca3af' stroke-width='1.5'><path d='M6 8l4 4 4-4'/></svg>\")] [background-position:right_0.75rem_center] [background-repeat:no-repeat]",
          className,
        )}
      >
        {children}
      </select>
    </label>
  );
}
