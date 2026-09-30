"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { ChevronRight, Search, ShieldCheck } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import { adminApi, ApiError, auth, type AdminUser } from "@/lib/api";
import { formatTugrik, relativeTime } from "@/lib/utils";

/**
 * Filter helper — exported so it can be unit tested without a Vitest
 * component-render for the whole page.
 */
export function filterUsers(
  users: AdminUser[],
  filter: "ALL" | "VERIFIED" | "UNVERIFIED",
  query: string,
): AdminUser[] {
  const q = query.trim().toLowerCase();
  return users.filter((u) => {
    if (filter === "VERIFIED" && !u.isVerified) return false;
    if (filter === "UNVERIFIED" && u.isVerified) return false;
    if (!q) return true;
    return (
      u.phoneNumber.toLowerCase().includes(q) ||
      (u.city?.toLowerCase().includes(q) ?? false) ||
      (u.companyName?.toLowerCase().includes(q) ?? false)
    );
  });
}

export default function UsersPage() {
  const router = useRouter();
  const [users, setUsers] = useState<AdminUser[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<"ALL" | "VERIFIED" | "UNVERIFIED">(
    "ALL",
  );
  const [pendingVerify, setPendingVerify] = useState<Set<number>>(new Set());

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    adminApi
      .users()
      .then(setUsers)
      .catch((e) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  const verify = async (id: number) => {
    setPendingVerify((s) => new Set(s).add(id));
    try {
      const updated = await adminApi.verify(id);
      setUsers((prev) =>
        prev ? prev.map((u) => (u.id === id ? updated : u)) : prev,
      );
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Алдаа гарлаа");
    } finally {
      setPendingVerify((s) => {
        const n = new Set(s);
        n.delete(id);
        return n;
      });
    }
  };

  const filtered = useMemo(
    () => (users ? filterUsers(users, filter, query) : []),
    [users, filter, query],
  );

  return (
    <>
      <PageHeader
        title="Хэрэглэгчид"
        description="Бүх бүртгэлтэй үзэгчид ба компаниуд"
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-64">
          <Search
            size={14}
            className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]"
          />
          <Input
            className="pl-9"
            placeholder="Утас, хот, компаниар хайх..."
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
        <CardHeader
          title={users === null ? "Ачаалж байна..." : `Нийт: ${filtered.length}`}
        />
        <CardBody className="p-0">
          {error && (
            <div className="border-b border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-5 py-3 text-xs text-[var(--color-danger)]">
              {error}
            </div>
          )}
          {users === null && !error ? (
            <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
              Хэрэглэгчдийн жагсаалт ачаалж байна...
            </div>
          ) : (
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
                  <th className="px-5 py-3 font-semibold text-right">Статус</th>
                  <th className="px-5 py-3 font-semibold text-right">Үйлдэл</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((u) => (
                  <tr
                    key={u.id}
                    className={`border-b border-[var(--color-divider)] last:border-0 ${
                      u.role === "COMPANY"
                        ? "hover:bg-[var(--color-surface-elevated)]/60"
                        : ""
                    }`}
                  >
                    <td className="px-5 py-3 font-mono text-[var(--color-text-primary)]">
                      {u.phoneNumber}
                    </td>
                    <td className="px-5 py-3 text-[var(--color-text-secondary)]">
                      {u.role === "COMPANY" ? (
                        <Link
                          href={`/admin/companies/${u.id}`}
                          className="inline-flex items-center gap-1 hover:text-[var(--color-text-primary)]"
                        >
                          <span className="font-semibold text-[var(--color-text-primary)]">
                            {u.companyName ?? "—"}
                          </span>
                          <span className="text-[var(--color-text-muted)]">
                            (Компани)
                          </span>
                          <ChevronRight
                            size={12}
                            className="text-[var(--color-text-muted)]"
                          />
                        </Link>
                      ) : u.role === "ADMIN" ? (
                        <span className="text-[var(--color-primary)]">Админ</span>
                      ) : (
                        <span>
                          {u.gender === "MALE" ? "♂" : u.gender === "FEMALE" ? "♀" : ""}
                          {u.age !== null ? ` · ${u.age} нас` : ""}
                        </span>
                      )}
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
                            onClick={() => verify(u.id)}
                            disabled={pendingVerify.has(u.id)}
                          >
                            {pendingVerify.has(u.id)
                              ? "Хадгалж байна..."
                              : "Баталгаажуулах"}
                          </Button>
                        )}
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
          )}
        </CardBody>
      </Card>
    </>
  );
}
