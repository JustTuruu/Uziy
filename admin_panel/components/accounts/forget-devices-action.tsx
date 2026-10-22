"use client";

import { useState } from "react";
import { MonitorX } from "lucide-react";
import { Button, ConfirmDialog, DEVICE_TRUST_DAYS } from "@uziy/ui";
import { adminApi, ApiError, GENERIC_ERROR_MESSAGE } from "@/lib/api";

export const FORGET_DEVICES_COPY = {
  action: "Төхөөрөмжүүдийг мартах",
  title: "Төхөөрөмжүүдийг мартах уу?",
  message: (name: string) =>
    `${name} дараагийн нэвтрэлтдээ хөтөч бүрээс утсаараа SMS илгээж баталгаажуулна. ` +
    `Танигдсан хөтчүүд (${DEVICE_TRUST_DAYS} хоног) бүгд мартагдана.`,
  confirm: "Мартах",
  done: "Төхөөрөмжүүд мартагдлаа. Дараагийн нэвтрэлтэд SMS шаардана.",
} as const;

interface ForgetDevicesActionProps {
  userId: number;
  /** Who the dialog talks about (the company's name). */
  accountName: string;
}

/**
 * Makes every browser the account proved its phone from a stranger again (`POST /admin/users/{id}/trusted-devices/
 * forget`), after a confirmation. Use it when a laptop is lost or a person leaves the company.
 */
export function ForgetDevicesAction({ userId, accountName }: ForgetDevicesActionProps) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null);

  const forget = async () => {
    setBusy(true);
    try {
      await adminApi.forgetTrustedDevices(userId);
      setResult({ ok: true, text: FORGET_DEVICES_COPY.done });
    } catch (e) {
      setResult({ ok: false, text: e instanceof ApiError ? e.message : GENERIC_ERROR_MESSAGE });
    } finally {
      setBusy(false);
      setOpen(false);
    }
  };

  return (
    <div className="flex flex-col items-end gap-1">
      <Button
        type="button"
        variant="secondary"
        size="sm"
        leftIcon={<MonitorX size={14} />}
        onClick={() => {
          setResult(null);
          setOpen(true);
        }}
      >
        {FORGET_DEVICES_COPY.action}
      </Button>
      {result && (
        <p
          role={result.ok ? "status" : "alert"}
          className={
            result.ok
              ? "text-xs text-[var(--color-text-secondary)]"
              : "text-xs text-[var(--color-danger)]"
          }
        >
          {result.text}
        </p>
      )}
      <ConfirmDialog
        open={open}
        title={FORGET_DEVICES_COPY.title}
        message={FORGET_DEVICES_COPY.message(accountName)}
        confirmLabel={FORGET_DEVICES_COPY.confirm}
        tone="danger"
        busy={busy}
        onConfirm={() => void forget()}
        onCancel={() => setOpen(false)}
      />
    </div>
  );
}
