import { Card, CardBody, CardHeader } from "@uziy/ui";
import type { AccessLogEntry } from "@admin/lib/api";

const ACTION_LABELS: Record<string, string> = {
  VIEW_OVERVIEW: "Самбар харсан",
  VIEW_QUESTIONS: "Асуултын жагсаалт харсан",
  VIEW_QUESTION: "Асуултын үр дүн харсан",
  VIEW_SEGMENTS: "Сегмент харсан",
  EXPORT_CSV: "CSV татсан",
  VIEW_ACCESS_LOG: "Бүртгэл харсан",
  VIEW_USERS: "Хэрэглэгчдийн жагсаалт харсан",
  VIEW_USER: "Хэрэглэгчийн мэдээлэл харсан",
  VIEW_COMPANIES: "Компаниудын жагсаалт харсан",
  VIEW_PAYOUTS: "Мөнгө татах хүсэлтүүд харсан",
  VIEW_PAYOUT_HISTORY: "Мөнгө татах түүх харсан",
};

export function actionLabel(action: string): string {
  return ACTION_LABELS[action] ?? action;
}

/** Who looked at which statistic, newest first. */
export function AccessLogTable({ entries }: { entries: AccessLogEntry[] }) {
  return (
    <Card>
      <CardHeader
        title="Хандалтын бүртгэл"
        description="Статистик, хэрэглэгчийн болон мөнгө татах мэдээлэлд хандсан бүр (сүүлийн 200)"
      />
      <CardBody className="overflow-x-auto p-0">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-[var(--color-divider)] text-left text-xs text-[var(--color-text-secondary)]">
              <th className="px-5 py-2 font-medium">Хэзээ</th>
              <th className="px-5 py-2 font-medium">Хэн</th>
              <th className="px-5 py-2 font-medium">Юу</th>
              <th className="px-5 py-2 font-medium">Дэлгэрэнгүй</th>
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.id} className="border-b border-[var(--color-divider)]">
                <td className="whitespace-nowrap px-5 py-2 tabular-nums">
                  {new Date(e.at).toLocaleString("mn-MN")}
                </td>
                <td className="px-5 py-2 tabular-nums">{e.adminPhone}</td>
                <td className="px-5 py-2">{actionLabel(e.action)}</td>
                <td className="px-5 py-2 text-[var(--color-text-secondary)]">{e.detail || "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </CardBody>
    </Card>
  );
}
