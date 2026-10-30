import { Button } from "@uziy/ui";

/** What the admin hands over after opening an account; the password is shown here once and never again. */
export interface HandOver {
  title: string;
  note: string;
  phoneNumber: string;
  password: string;
}

export function HandOverNotice({ handOver, onDismiss }: { handOver: HandOver; onDismiss: () => void }) {
  return (
    <div
      role="status"
      className="mb-4 rounded-lg border border-[color-mix(in_oklab,var(--color-success)_30%,transparent)] bg-[color-mix(in_oklab,var(--color-success)_8%,transparent)] p-3 text-xs"
    >
      <div className="font-semibold text-[var(--color-success)]">{handOver.title}</div>
      <p className="mt-1 text-[var(--color-text-secondary)]">{handOver.note}</p>
      <dl className="mt-2 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
        <dt className="text-[var(--color-text-muted)]">Утас</dt>
        <dd className="font-mono tabular-nums">{handOver.phoneNumber}</dd>
        <dt className="text-[var(--color-text-muted)]">Нууц үг</dt>
        <dd className="font-mono" data-testid="handover-password">
          {handOver.password}
        </dd>
      </dl>
      <Button type="button" size="sm" variant="ghost" className="mt-2" onClick={onDismiss}>
        Ойлголоо
      </Button>
    </div>
  );
}
