"use client";

import { useMemo } from "react";
import { CircleAlert } from "lucide-react";
import { NumericInput } from "@uziy/ui";
import {
  MAX_MONEY_DIGITS,
  computeCampaignPricing,
  describePricing,
  pricingErrorMessage,
  type PricingMode,
  type PricingResult,
} from "@/lib/pricing";
import { cn, formatNumber, formatTugrik, parseIntInput } from "@/lib/utils";

/**
 * Raw state of the budget step. Only the DRIVER field's text matters (the
 * one the company typed in last, per `mode`); the other field always shows
 * the value computed from it.
 */
export interface BudgetFieldsValue {
  budgetText: string;
  mode: PricingMode;
  viewersText: string;
  rewardText: string;
}

export interface PricingSettings {
  commissionPercent: number;
  minRewardPerViewer: number;
}

export const DEFAULT_BUDGET_FIELDS: BudgetFieldsValue = {
  budgetText: "1000000",
  mode: "VIEWERS",
  viewersText: "1000",
  rewardText: "",
};

/** Prices the current field state (same function the server mirrors). */
export function pricingFromFields(
  value: BudgetFieldsValue,
  settings: PricingSettings,
): PricingResult {
  return computeCampaignPricing({
    budget: parseIntInput(value.budgetText),
    commissionPercent: settings.commissionPercent,
    minRewardPerViewer: settings.minRewardPerViewer,
    mode: value.mode,
    targetViewers: parseIntInput(value.viewersText),
    rewardPerViewer: parseIntInput(value.rewardText),
  });
}

const COMPUTED_HINT = "Автоматаар тооцоолсон";

/**
 * Total budget + two linked fields: "how many viewers" and "how much each
 * viewer gets". Typing in either one makes it the driver and the other is
 * recomputed; a summary shows the platform commission and the amount due.
 */
export function CampaignBudgetFields({
  value,
  onChange,
  settings,
}: {
  value: BudgetFieldsValue;
  onChange: (next: BudgetFieldsValue) => void;
  settings: PricingSettings;
}) {
  const pricing = useMemo(
    () => pricingFromFields(value, settings),
    [value, settings],
  );

  // With a missing input there is nothing sensible to show in the
  // computed field — leave it blank rather than a misleading "0".
  const inputMissing =
    pricing.error === "BUDGET_INVALID" ||
    pricing.error === "VIEWERS_INVALID" ||
    pricing.error === "REWARD_INVALID";
  const computed = (n: number) => (inputMissing ? "" : String(n));

  const viewersDriven = value.mode === "VIEWERS";
  const viewersShown = viewersDriven
    ? value.viewersText
    : computed(pricing.targetViewers);
  const rewardShown = viewersDriven
    ? computed(pricing.rewardPerViewer)
    : value.rewardText;

  const ok = pricing.error === null;
  const explanation = describePricing(pricing);
  const computedCls =
    "border-dashed bg-[var(--color-surface-elevated)] text-[var(--color-text-secondary)]";

  return (
    <div className="space-y-5">
      <NumericInput
        label="Нийт төсөв (₮)"
        maxLength={MAX_MONEY_DIGITS}
        value={value.budgetText}
        onValueChange={(text) => onChange({ ...value, budgetText: text })}
        hint="Энэ аянд зарцуулах дээд дүн"
      />

      <div>
        <div className="mb-3 text-xs text-[var(--color-text-secondary)]">
          Аль нэгийг нь оруулахад нөгөөг нь автоматаар тооцоолно.
        </div>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <NumericInput
            label="Хүрэх үзэгчийн тоо"
            maxLength={MAX_MONEY_DIGITS}
            value={viewersShown}
            onValueChange={(text) =>
              onChange({ ...value, mode: "VIEWERS", viewersText: text })
            }
            hint={viewersDriven ? undefined : COMPUTED_HINT}
            className={viewersDriven ? undefined : computedCls}
          />
          <NumericInput
            label="Нэг үзэгчид олгох урамшуулал (₮)"
            maxLength={MAX_MONEY_DIGITS}
            value={rewardShown}
            onValueChange={(text) =>
              onChange({ ...value, mode: "REWARD", rewardText: text })
            }
            hint={viewersDriven ? COMPUTED_HINT : undefined}
            className={viewersDriven ? computedCls : undefined}
          />
        </div>
      </div>

      {pricing.error && (
        <div
          role="alert"
          className="flex items-start gap-2 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]"
        >
          <CircleAlert size={14} className="mt-0.5 shrink-0" />
          <span>
            {pricingErrorMessage(pricing.error, settings.minRewardPerViewer)}
          </span>
        </div>
      )}

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <SummaryTile
          label="Нэг үзэгчид олгох урамшуулал"
          value={ok ? formatTugrik(pricing.rewardPerViewer) : "—"}
        />
        <SummaryTile
          label="Хүрэх үзэгчийн тоо"
          value={ok ? formatNumber(pricing.targetViewers) : "—"}
        />
        <SummaryTile
          label={`Платформын шимтгэл (${settings.commissionPercent}%)`}
          value={ok ? formatTugrik(pricing.commissionTotal) : "—"}
          tone="warn"
        />
        <SummaryTile
          label="Төлөх дүн"
          value={ok ? formatTugrik(pricing.payable) : "—"}
          tone="primary"
        />
      </div>

      {explanation && (
        <div className="space-y-1 rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)] p-4 text-xs text-[var(--color-text-secondary)]">
          <div>
            <b className="text-[var(--color-text-primary)]">Хэрхэн:</b>{" "}
            {explanation}
          </div>
          {ok && pricing.unused > 0 && (
            <div>
              Үлдэгдэл {formatTugrik(pricing.unused)} төлбөрт орохгүй.
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function SummaryTile({
  label,
  value,
  tone = "neutral",
}: {
  label: string;
  value: string;
  tone?: "neutral" | "primary" | "warn";
}) {
  const toneCls = {
    neutral: "border-[var(--color-divider)] bg-[var(--color-surface-elevated)]",
    primary:
      "border-[color-mix(in_oklab,var(--color-primary)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-primary)_10%,transparent)]",
    warn: "border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)]",
  }[tone];

  return (
    <div className={cn("rounded-xl border p-3", toneCls)}>
      <div className="mb-1 text-[10px] uppercase tracking-wide text-[var(--color-text-secondary)]">
        {label}
      </div>
      <div
        className={cn(
          "font-mono text-lg font-bold",
          tone === "primary"
            ? "text-[var(--color-primary)]"
            : "text-[var(--color-text-primary)]",
        )}
      >
        {value}
      </div>
    </div>
  );
}
