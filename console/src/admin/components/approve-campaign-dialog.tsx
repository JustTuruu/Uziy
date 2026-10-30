import { useEffect, useState } from "react";
import { ConfirmDialog, NumericInput, parseIntInput } from "@uziy/ui";
import { platformSettingsApi, type Campaign } from "@admin/lib/api";
import { splitAt } from "@admin/lib/commission";
import { formatNumber, formatTugrik } from "@admin/lib/utils";

/**
 * Approving a paid campaign sets its own commission (owner, 2026-10-30). The field starts at the percentage the
 * campaign was priced with (its kind's default); the admin sees what one viewer will then get before confirming.
 * Used by the moderation queue and the campaign page alike.
 */
export function ApproveCampaignDialog({
  campaign,
  busy,
  onApprove,
  onCancel,
}: {
  /** The campaign to approve; null keeps the dialog closed. */
  campaign: Campaign | null;
  busy: boolean;
  onApprove: (commissionPercent: number) => void;
  onCancel: () => void;
}) {
  const [percentText, setPercentText] = useState("");
  const [minReward, setMinReward] = useState<number | null>(null);
  const [settingsError, setSettingsError] = useState<string | null>(null);
  const [shownFor, setShownFor] = useState<number | null>(null);

  // A new campaign starts from its own percentage (state adjusted while rendering, not in an effect).
  if (campaign && campaign.id !== shownFor) {
    setShownFor(campaign.id);
    setPercentText(campaign.commissionPercent === null ? "" : String(campaign.commissionPercent));
  }

  // The minimum reward decides which percentages are allowed; read once, when the dialog first opens.
  const opened = campaign !== null;
  useEffect(() => {
    if (!opened) return;
    platformSettingsApi
      .get()
      .then((s) => setMinReward(s.minRewardPerViewer))
      .catch((e) => setSettingsError(e instanceof Error ? e.message : "Тохиргоо ачаалж чадсангүй"));
  }, [opened]);

  const percent = parseIntInput(percentText);
  const split = campaign && minReward !== null ? splitAt(campaign, percent, minReward) : null;

  return (
    <ConfirmDialog
      open={campaign !== null}
      title="Судалгааг баталгаажуулах"
      confirmLabel="Баталгаажуулах"
      busy={busy}
      confirmDisabled={split === null || split.error !== null}
      onConfirm={() => onApprove(percent)}
      onCancel={onCancel}
      message={
        campaign && (
          <div className="space-y-3">
            <p>
              Компанийн төлсөн {formatTugrik(campaign.totalBudget)} өөрчлөгдөхгүй. Шимтгэлээс хамаарч нэг
              үзэгчид олгох урамшуулал өөрчлөгдөнө.
            </p>
            <NumericInput
              label="Энэ судалгааны шимтгэл (%)"
              value={percentText}
              onValueChange={setPercentText}
              error={split?.error ?? undefined}
            />
            {split && split.error === null && (
              <dl className="grid grid-cols-2 gap-x-4 gap-y-1 text-xs">
                <dt className="text-[var(--color-text-muted)]">Нэг үзэгчид олгох</dt>
                <dd className="text-right font-mono">{formatTugrik(split.rewardPerViewer)}</dd>
                <dt className="text-[var(--color-text-muted)]">Хүрэх үзэгч</dt>
                <dd className="text-right font-mono">{formatNumber(campaign.targetViewers ?? 0)}</dd>
                <dt className="text-[var(--color-text-muted)]">Платформын орлого</dt>
                <dd className="text-right font-mono">{formatTugrik(split.commissionTotal)}</dd>
              </dl>
            )}
            {minReward === null && (
              <p className="text-xs text-[var(--color-text-muted)]">{settingsError ?? "Тохиргоо ачаалж байна..."}</p>
            )}
          </div>
        )
      }
    />
  );
}
