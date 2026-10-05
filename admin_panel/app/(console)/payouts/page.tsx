"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Check, ShieldAlert, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/page-header";
import { adminApi, ApiError, auth, type Payout } from "@/lib/api";
import { formatTugrik, relativeTime } from "@/lib/utils";

export default function PayoutsPage() {
  const router = useRouter();
  const [pending, setPending] = useState<Payout[] | null>(null);
  const [history, setHistory] = useState<Payout[] | null>(null);
  const [decidingId, setDecidingId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    const onErr = (e: unknown) => {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        auth.clear();
        router.replace("/login");
        return;
      }
      setError(e instanceof Error ? e.message : "Алдаа гарлаа");
    };
    adminApi.pendingPayouts().then(setPending).catch(onErr);
    adminApi.payoutHistory().then(setHistory).catch(onErr);
  }, [router]);

  const decide = async (id: number, decision: "APPROVED" | "REJECTED") => {
    setDecidingId(id);
    try {
      const reason =
        decision === "REJECTED"
          ? (window.prompt("Татгалзсан шалтгаан:") ?? undefined)
          : undefined;
      if (decision === "REJECTED" && !reason) {
        setDecidingId(null);
        return;
      }
      const updated = await adminApi.decidePayout(id, decision, reason);
      // Move the decided row from the pending queue to the top of the
      // history table so the admin sees their action reflected immediately
      // without having to refresh.
      setPending((prev) => (prev ? prev.filter((p) => p.id !== id) : prev));
      setHistory((prev) => (prev ? [updated, ...prev] : [updated]));
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Алдаа гарлаа");
    } finally {
      setDecidingId(null);
    }
  };

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
              мэдээлэлтэй тохирч байвал <b>Батлах</b>. Тохирохгүй тохиолдолд{" "}
              <b>Татгалзах</b> сонгож, шалтгааныг зааж өгнө. Эхний удаагийн
              баталгаажсан таталтад хэрэглэгчийн <b>is_verified = TRUE</b>{" "}
              болно. Мөнгө шилжүүлэх ажиллагаа одоохондоо гараар хийгдэнэ.
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="mb-4 rounded-xl border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-4 py-3 text-xs text-[var(--color-danger)]">
          {error}
        </div>
      )}

      <Card>
        <CardHeader
          title={
            pending === null
              ? "Ачаалж байна..."
              : `Хүлээгдэж буй (${pending.length})`
          }
          description="Хамгийн эртний хүсэлт эхэнд байрлана"
        />
        <CardBody className="p-0">
          {pending === null ? (
            <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
              Ачаалж байна...
            </div>
          ) : (
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
                          disabled={decidingId === p.id}
                        >
                          Татгалзах
                        </Button>
                        <Button
                          size="sm"
                          variant="success"
                          leftIcon={<Check size={12} />}
                          onClick={() => decide(p.id, "APPROVED")}
                          disabled={decidingId === p.id}
                        >
                          Батлах
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </CardBody>
      </Card>

      <Card className="mt-6">
        <CardHeader
          title={
            history === null
              ? "Түүх ачаалж байна..."
              : `Гүйлгээний түүх (${history.length})`
          }
          description="Батлагдсан + татгалзсан бүх хүсэлт, шинэ нь эхэнд"
        />
        <CardBody className="p-0">
          {history === null ? (
            <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
              Ачаалж байна...
            </div>
          ) : history.length === 0 ? (
            <div className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]">
              Хараахан шийдвэрлэгдсэн хүсэлт байхгүй.
            </div>
          ) : (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                  <th className="px-5 py-3 font-semibold">Хэрэглэгч</th>
                  <th className="px-5 py-3 font-semibold">Данс</th>
                  <th className="px-5 py-3 font-semibold text-right">Дүн</th>
                  <th className="px-5 py-3 font-semibold">Шийдвэр</th>
                  <th className="px-5 py-3 font-semibold text-right">Төлөв</th>
                </tr>
              </thead>
              <tbody>
                {history.map((p) => (
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
                    <td className="px-5 py-3">
                      <div className="font-mono text-[var(--color-text-primary)]">
                        {p.bank}
                      </div>
                      <div className="text-xs text-[var(--color-text-muted)]">
                        {p.accountNumber}
                      </div>
                    </td>
                    <td className="px-5 py-3 text-right font-mono">
                      {formatTugrik(p.amount)}
                    </td>
                    <td className="px-5 py-3">
                      <div className="text-xs text-[var(--color-text-muted)]">
                        {p.decidedAt ? relativeTime(p.decidedAt) : "—"}
                      </div>
                      {p.status === "REJECTED" && p.rejectReason && (
                        <div className="text-xs text-[var(--color-danger)]">
                          {p.rejectReason}
                        </div>
                      )}
                    </td>
                    <td className="px-5 py-3 text-right">
                      <Badge
                        tone={p.status === "APPROVED" ? "success" : "danger"}
                      >
                        {p.status === "APPROVED" ? "Батлагдсан" : "Татгалзсан"}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </CardBody>
      </Card>
    </>
  );
}
