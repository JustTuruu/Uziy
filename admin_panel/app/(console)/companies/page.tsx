"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Building2, Plus } from "lucide-react";
import { Button, Card, CardBody, CardHeader, FormError, Input, PageHeader, TableScroll } from "@uziy/ui";
import {
  ApiError,
  auth,
  companiesApi,
  GENERIC_ERROR_MESSAGE,
  type CompanyAccount,
} from "@/lib/api";
import { COMPANY_NAME_MAX, companyFormError, type CompanyForm } from "@/lib/account-form";
import { CredentialFields } from "@/components/accounts/credential-fields";
import { HandOverNotice, type HandOver } from "@/components/accounts/handover-notice";
import { formatDate, formatPhone } from "@/lib/utils";

const EMPTY_FORM: CompanyForm = { companyName: "", phoneNumber: "", password: "" };

export default function CompaniesPage() {
  const router = useRouter();
  const [companies, setCompanies] = useState<CompanyAccount[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [form, setForm] = useState<CompanyForm>(EMPTY_FORM);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [handOver, setHandOver] = useState<HandOver | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    companiesApi
      .list()
      .then(setCompanies)
      .catch((e: unknown) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setLoadError(e instanceof ApiError ? e.message : GENERIC_ERROR_MESSAGE);
      });
  }, [router]);

  const set = (patch: Partial<CompanyForm>) => setForm((f) => ({ ...f, ...patch }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const problem = companyFormError(form);
    setFormError(problem);
    if (problem) return;
    setSaving(true);
    try {
      const created = await companiesApi.create({
        ...form,
        companyName: form.companyName.trim(),
      });
      setCompanies((list) => [created, ...(list ?? [])]);
      setHandOver({
        title: `«${created.companyName}» компанийн данс үүслээ`,
        note: "Нэвтрэх мэдээллийг компанид өгнө үү. Нууц үг дахин харагдахгүй.",
        phoneNumber: created.phoneNumber,
        password: form.password,
      });
      setForm(EMPTY_FORM);
    } catch (err) {
      setFormError(err instanceof ApiError ? err.message : GENERIC_ERROR_MESSAGE);
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <PageHeader
        title="Компаниуд"
        description="Компанийн дансыг зөвхөн энд үүсгэнэ — компани өөрөө бүртгүүлэх боломжгүй"
      />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <Card>
          <CardHeader
            title={
              companies === null
                ? "Ачаалж байна..."
                : `Бүх компани (${companies.length})`
            }
            description="Шинэ нь эхэнд"
          />
          <CardBody className="p-0">
            {loadError ? (
              <div className="px-5 py-4 text-xs text-[var(--color-danger)]" role="alert">
                {loadError}
              </div>
            ) : companies === null ? (
              <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            ) : companies.length === 0 ? (
              <div className="px-5 py-10 text-center text-sm text-[var(--color-text-muted)]">
                Одоогоор компани алга. Баруун талын маягтаар нэмнэ үү.
              </div>
            ) : (
              <TableScroll>
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                      <th className="px-5 py-3 font-semibold">Компани</th>
                      <th className="px-5 py-3 font-semibold">Утас</th>
                      <th className="px-5 py-3 text-right font-semibold">Судалгаа</th>
                      <th className="px-5 py-3 text-right font-semibold">Үүсгэсэн</th>
                    </tr>
                  </thead>
                  <tbody>
                    {companies.map((c) => (
                      <tr
                        key={c.id}
                        className="border-b border-[var(--color-divider)] last:border-0"
                      >
                        <td className="px-5 py-3">
                          <Link
                            href={`/companies/${c.id}`}
                            className="inline-flex items-center gap-2 font-semibold text-[var(--color-text-primary)] hover:text-[var(--color-primary)]"
                          >
                            <Building2 size={14} className="text-[var(--color-text-muted)]" />
                            {c.companyName || "—"}
                          </Link>
                        </td>
                        <td className="whitespace-nowrap px-5 py-3 font-mono tabular-nums text-[var(--color-text-secondary)]">
                          {formatPhone(c.phoneNumber)}
                        </td>
                        <td className="px-5 py-3 text-right tabular-nums">{c.campaignCount}</td>
                        <td className="px-5 py-3 text-right text-xs text-[var(--color-text-muted)]">
                          {formatDate(c.createdAt)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </TableScroll>
            )}
          </CardBody>
        </Card>

        <Card className="self-start">
          <CardHeader
            title="Компани нэмэх"
            description="Түр нууц үгийг компанид өөрөө хүлээлгэн өгнө"
          />
          <CardBody>
            {handOver && (
              <HandOverNotice handOver={handOver} onDismiss={() => setHandOver(null)} />
            )}

            <form onSubmit={submit} noValidate className="space-y-4">
              <Input
                label="Компанийн нэр"
                maxLength={COMPANY_NAME_MAX}
                value={form.companyName}
                onChange={(e) => set({ companyName: e.target.value })}
              />
              <CredentialFields value={form} onChange={set} />
              {formError && <FormError message={formError} />}
              <Button
                type="submit"
                className="w-full"
                disabled={saving}
                leftIcon={<Plus size={14} />}
              >
                {saving ? "Үүсгэж байна..." : "Компани нэмэх"}
              </Button>
            </form>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
