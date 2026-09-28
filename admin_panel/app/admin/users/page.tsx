"use client";

import { useMemo, useState } from "react";
import { Search, ShieldCheck, UserX } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import { mockUsers } from "@/lib/mock-data";
import { formatTugrik, relativeTime } from "@/lib/utils";

export default function UsersPage() {
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<"ALL" | "VERIFIED" | "UNVERIFIED">(
    "ALL",
  );

  const filtered = useMemo(() => {
    return mockUsers.filter((u) => {
      if (filter === "VERIFIED" && !u.isVerified) return false;
      if (filter === "UNVERIFIED" && u.isVerified) return false;
      if (
        query &&
        !u.phoneNumber.toLowerCase().includes(query.toLowerCase()) &&
        !u.city?.toLowerCase().includes(query.toLowerCase())
      ) {
        return false;
      }
      return true;
    });
  }, [query, filter]);

  return (
    <>
      <PageHeader
        title="Хэрэглэгчид"
        description="Бүх бүртгэлтэй үзэгчид"
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-64">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
          />
          <Input
            className="pl-9"
            placeholder="Утас, хотоор хайх..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <div className="flex gap-1 rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface)] p-1">
          {(
            [
              ["ALL", "Бүгд"],
              ["VERIFIED", "Баталгаажсан"],
              ["UNVERIFIED", "Баталгаажаагүй"],
            ] as const
          ).map(([k, label]) => (
            <button
              key={k}
              onClick={() => setFilter(k)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${
                filter === k
                  ? "bg-[var(--color-primary)] text-black"
                  : "text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <Card>
        <CardHeader title={`Нийт: ${filtered.length}`} />
        <CardBody className="p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                <th className="px-5 py-3 font-semibold">Утас</th>
                <th className="px-5 py-3 font-semibold">Профайл</th>
                <th className="px-5 py-3 font-semibold">Хот</th>
                <th className="px-5 py-3 font-semibold">Бүртгэсэн</th>
                <th className="px-5 py-3 font-semibold text-right">
                  Үлдэгдэл
                </th>
                <th className="px-5 py-3 font-semibold text-right">
                  Статус
                </th>
                <th className="px-5 py-3 font-semibold text-right">Үйлдэл</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((u) => (
                <tr
                  key={u.id}
                  className="border-b border-[var(--color-divider)] last:border-0"
                >
                  <td className="px-5 py-3 font-mono text-[var(--color-text-primary)]">
                    {u.phoneNumber}
                  </td>
                  <td className="px-5 py-3 text-[var(--color-text-secondary)]">
                    {u.gender === "MALE" ? "♂" : "♀"} · {u.age} нас
                  </td>
                  <td className="px-5 py-3 text-[var(--color-text-secondary)]">
                    {u.city ?? "—"}
                  </td>
                  <td className="px-5 py-3 text-[var(--color-text-muted)]">
                    {relativeTime(u.createdAt)}
                  </td>
                  <td className="px-5 py-3 text-right font-mono text-[var(--color-text-primary)]">
                    {formatTugrik(u.balance)}
                  </td>
                  <td className="px-5 py-3 text-right">
                    <Badge tone={u.isVerified ? "success" : "neutral"}>
                      {u.isVerified ? "Баталгаажсан" : "Баталгаажаагүй"}
                    </Badge>
                  </td>
                  <td className="px-5 py-3">
                    <div className="flex justify-end gap-2">
                      {!u.isVerified && (
                        <Button
                          size="sm"
                          variant="secondary"
                          leftIcon={<ShieldCheck size={12} />}
                        >
                          Баталгаажуулах
                        </Button>
                      )}
                      <Button
                        size="sm"
                        variant="ghost"
                        leftIcon={<UserX size={12} />}
                      >
                        Хаах
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
              {filtered.length === 0 && (
                <tr>
                  <td
                    colSpan={7}
                    className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]"
                  >
                    Хэрэглэгч олдсонгүй.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </CardBody>
      </Card>
    </>
  );
}
