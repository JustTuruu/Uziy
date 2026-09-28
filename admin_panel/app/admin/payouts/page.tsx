"use client";

import { useState } from "react";
import { Check, ShieldAlert, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { mockPayouts, type Payout } from "@/lib/mock-data";
import { formatTugrik, relativeTime } from "@/lib/utils";

export default function PayoutsPage() {
  const [rows, setRows] = useState<Payout[]>(mockPayouts);

  const decide = (id: number, decision: "APPROVED" | "REJECTED") => {
    setRows((r) =>
      r.map((p) => (p.id === id ? { ...p, status: decision } : p)),
    );
    // TODO: POST /admin/payouts/{id}/decision. On APPROVED for a first payout,
    // the backend must also flip users.is_verified = TRUE (spec §4A).
  };

  const pending = rows.filter((p) => p.status === "PENDING");
  const decided = rows.filter((p) => p.status !== "PENDING");

  return (
    <>
      <PageHeader
        title="Мөнгө татах хүсэлтүүд"
        description="Дансны нэрийг бүртгэлтэй мэдээлэлтэй тулгах ⇒ баталгаажуулна"
      />

      <div className="mb-4 rounded-xl border border-[color-mix(in_oklab,var(--color-warning)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-warning)_10%,transparent)] p-4 text-xs">
        <div className="flex items-start gap-2">
          <ShieldAlert
            size={16}
            className="mt-0.5 shrink-0 text-[var(--color-warning)]"
          />
          <div>
            <div className="font-semibold text-[var(--color-warning)]">
              Хэрхэн шалгах вэ
            </div>
            <div className="mt-1 text-[var(--color-text-primary)]">
              Дансны эзэмшигчийн нэр болон регистр нь хэрэглэгчийн бүртгэлтэй
              мэдээлэлтэй тохирч байвал <b>Batlah</b>. Тохирохгүй тохиолдолд{" "}
              <b>Tsutsalah</b> сонгож, шалтгааныг зааж өгнө. Эхний удаагийн
              таталт баталгаажсан хэрэглэгч{" "}
              <b>is_verified = TRUE</b> болно.
            </div>
          </div>
        </div>
      </div>

      <Card>
        <CardHeader
          title={`Хүлээгдэж буй (${pending.length})`}
          description="Хамгийн эртний хүсэлт эхэнд байрлана"
        />
        <CardBody className="p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                <th className="px-5 py-3 font-semibold">Хэрэглэгч</th>
                <th className="px-5 py-3 font-semibold">Данс</th>
                <th className="px-5 py-3 font-semibold">Регистр</th>
                <th className="px-5 py-3 font-semibold text-right">Дүн</th>
                <th className="px-5 py-3 font-semibold text-right">Үйлдэл</th>
              </tr>
            </thead>
            <tbody>
              {pending.length === 0 && (
                <tr>
                  <td
                    colSpan={5}
                    className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]"
                  >
                    Хүлээгдэж буй хүсэлт байхгүй.
                  </td>
                </tr>
              )}
              {pending.map((p) => (
                <tr
                  key={p.id}
                  className="border-b border-[var(--color-divider)] last:border-0"
                >
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-2">
                      <div className="font-semibold">{p.accountName}</div>
                      {p.isFirstPayout && (
                        <Badge tone="warning">Эхний таталт</Badge>
                      )}
                    </div>
                    <div className="text-xs text-[var(--color-text-muted)]">
                      {p.userPhone} · {relativeTime(p.requestedAt)}
                    </div>
                  </td>
                  <td className="px-5 py-4">
                    <div className="font-mono text-[var(--color-text-primary)]">
                      {p.bank}
                    </div>
                    <div className="text-xs text-[var(--color-text-muted)]">
                      {p.accountNumber}
                    </div>
                  </td>
                  <td className="px-5 py-4 font-mono text-[var(--color-text-primary)]">
                    {p.nationalId}
                  </td>
                  <td className="px-5 py-4 text-right font-mono text-lg font-bold text-[var(--color-primary)]">
                    {formatTugrik(p.amount)}
                  </td>
                  <td className="px-5 py-4">
                    <div className="flex justify-end gap-2">
                      <Button
                        size="sm"
                        variant="secondary"
                        leftIcon={<X size={12} />}
                        onClick={() => decide(p.id, "REJECTED")}
                      >
                        Цуцлах
                      </Button>
                      <Button
                        size="sm"
                        variant="success"
                        leftIcon={<Check size={12} />}
                        onClick={() => decide(p.id, "APPROVED")}
                      >
                        Батлах
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardBody>
      </Card>

      <Card className="mt-6">
        <CardHeader title={`Шийдвэрлэсэн (${decided.length})`} />
        <CardBody className="p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                <th className="px-5 py-3 font-semibold">Хэрэглэгч</th>
                <th className="px-5 py-3 font-semibold text-right">Дүн</th>
                <th className="px-5 py-3 font-semibold text-right">Төлөв</th>
              </tr>
            </thead>
            <tbody>
              {decided.map((p) => (
                <tr
                  key={p.id}
                  className="border-b border-[var(--color-divider)] last:border-0"
                >
                  <td className="px-5 py-3">
                    <div className="text-sm font-semibold">
                      {p.accountName}
                    </div>
                    <div className="text-xs text-[var(--color-text-muted)]">
                      {p.userPhone}
                    </div>
                  </td>
                  <td className="px-5 py-3 text-right font-mono">
                    {formatTugrik(p.amount)}
                  </td>
                  <td className="px-5 py-3 text-right">
                    <Badge
                      tone={p.status === "APPROVED" ? "success" : "danger"}
                    >
                      {p.status === "APPROVED" ? "Батлагдсан" : "Цуцлагдсан"}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardBody>
      </Card>
    </>
  );
}
