import { useRouter } from "@shared/navigation";
import { useEffect, useState } from "react";
import { Plus, ShieldCheck } from "lucide-react";
import { Badge, Button, Card, CardBody, CardHeader, FormError, PageHeader, TableScroll } from "@uziy/ui";
import {
  ApiError,
  adminsApi,
  auth,
  GENERIC_ERROR_MESSAGE,
  useStoredUser,
  type AdminAccount,
} from "@admin/lib/api";
import { credentialsError, type AccountCredentials } from "@admin/lib/account-form";
import { CredentialFields } from "@admin/components/accounts/credential-fields";
import { HandOverNotice, type HandOver } from "@admin/components/accounts/handover-notice";
import { formatDate, formatPhone } from "@admin/lib/utils";

const EMPTY_FORM: AccountCredentials = { phoneNumber: "", password: "" };

export default function AdminsPage() {
  const router = useRouter();
  const myId = useStoredUser()?.id ?? null;
  const [admins, setAdmins] = useState<AdminAccount[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [form, setForm] = useState<AccountCredentials>(EMPTY_FORM);
  const [formError, setFormError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [handOver, setHandOver] = useState<HandOver | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    adminsApi
      .list()
      .then(setAdmins)
      .catch((e: unknown) => {
        if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
          auth.clear();
          router.replace("/login");
          return;
        }
        setLoadError(e instanceof ApiError ? e.message : GENERIC_ERROR_MESSAGE);
      });
  }, [router]);

  const set = (patch: Partial<AccountCredentials>) => setForm((f) => ({ ...f, ...patch }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const problem = credentialsError(form);
    setFormError(problem);
    if (problem) return;
    setSaving(true);
    try {
      const created = await adminsApi.create(form);
      setAdmins((list) => [created, ...(list ?? [])]);
      setHandOver({
        title: "Админы данс үүслээ",
        note:
          "Нэвтрэх мэдээллийг тухайн хүнд өөрт нь өгнө үү. Нэвтрэх бүрт энэ утаснаас SMS илгээж баталгаажуулна. Нууц үг дахин харагдахгүй.",
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
        title="Админууд"
        description="Админы дансыг зөвхөн өөр админ үүсгэнэ — хэн ч өөрөө админ болж бүртгүүлэх боломжгүй"
      />

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_22rem]">
        <Card>
          <CardHeader
            title={admins === null ? "Ачаалж байна..." : `Бүх админ (${admins.length})`}
            description="Шинэ нь эхэнд"
          />
          <CardBody className="p-0">
            {loadError ? (
              <div className="px-5 py-4 text-xs text-[var(--color-danger)]" role="alert">
                {loadError}
              </div>
            ) : admins === null ? (
              <div className="animate-pulse px-5 py-10 text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            ) : (
              <TableScroll>
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-[var(--color-divider)] text-left text-xs uppercase tracking-wide text-[var(--color-text-muted)]">
                      <th className="px-5 py-3 font-semibold">Утас</th>
                      <th className="px-5 py-3 text-right font-semibold">Үүсгэсэн</th>
                    </tr>
                  </thead>
                  <tbody>
                    {admins.map((a) => (
                      <tr key={a.id} className="border-b border-[var(--color-divider)] last:border-0">
                        <td className="px-5 py-3">
                          <span className="inline-flex items-center gap-2 font-mono tabular-nums text-[var(--color-text-primary)]">
                            <ShieldCheck size={14} className="text-[var(--color-text-muted)]" />
                            {formatPhone(a.phoneNumber)}
                            {a.id === myId && <Badge tone="primary">Та</Badge>}
                          </span>
                        </td>
                        <td className="px-5 py-3 text-right text-xs text-[var(--color-text-muted)]">
                          {formatDate(a.createdAt)}
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
            title="Админ нэмэх"
            description="Тухайн хүн нэвтрэх бүрт энэ утаснаасаа SMS илгээнэ"
          />
          <CardBody>
            {handOver && (
              <HandOverNotice handOver={handOver} onDismiss={() => setHandOver(null)} />
            )}

            <form onSubmit={submit} noValidate className="space-y-4">
              <CredentialFields value={form} onChange={set} />
              {formError && <FormError message={formError} />}
              <Button type="submit" className="w-full" disabled={saving} leftIcon={<Plus size={14} />}>
                {saving ? "Үүсгэж байна..." : "Админ нэмэх"}
              </Button>
            </form>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
