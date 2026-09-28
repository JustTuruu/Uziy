"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AlertCircle, DollarSign, Save } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardBody, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { PageHeader } from "@/components/page-header";
import {
  adminApi,
  ApiError,
  auth,
  platformSettingsApi,
  type PlatformSettings,
} from "@/lib/api";
import { formatTugrik } from "@/lib/utils";

export default function PricingPage() {
  const router = useRouter();

  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [cost, setCost] = useState("");
  const [reward, setReward] = useState("");
  const [loading, setLoading] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.getToken()) {
      router.replace("/login");
      return;
    }
    platformSettingsApi
      .get()
      .then((s) => {
        setSettings(s);
        setCost(String(s.surveyOnlyCostPerResponse));
        setReward(String(s.surveyOnlyRewardPerUser));
      })
      .catch((e) => {
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaved(false);

    const c = Number(cost);
    const r = Number(reward);
    if (!Number.isFinite(c) || c <= 0) {
      setError("Компанийн төлөх дүн 0-ээс их байх ёстой");
      return;
    }
    if (!Number.isFinite(r) || r <= 0) {
      setError("Хэрэглэгчид олгох дүн 0-ээс их байх ёстой");
      return;
    }
    if (r >= c) {
      setError("Хэрэглэгчид олгох дүн компанийн төлбөрөөс бага байх ёстой");
      return;
    }

    setLoading(true);
    try {
      const next = await adminApi.updateSettings({
        surveyOnlyCostPerResponse: c,
        surveyOnlyRewardPerUser: r,
      });
      setSettings(next);
      setSaved(true);
    } catch (e) {
      if (e instanceof ApiError && (e.status === 401 || e.status === 403)) {
        auth.clear();
        router.replace("/login");
        return;
      }
      setError(e instanceof ApiError ? e.message : "Хадгалж чадсангүй");
    } finally {
      setLoading(false);
    }
  };

  const commission =
    Number.isFinite(Number(cost)) && Number.isFinite(Number(reward))
      ? Math.max(0, Number(cost) - Number(reward))
      : 0;

  return (
    <>
      <PageHeader
        title="Судалгааны үнэ тохиргоо"
        description="Видеогүй судалгааны кампанийн үнийг платформ дээр төвлөрсөн байдлаар тохируулна"
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Одоогийн үнэ"
            description="Хадгалсны дараа шинэ санал болголтуудад мөрдөгдөнө"
          />
          <CardBody>
            {settings === null && !error ? (
              <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            ) : (
              <form onSubmit={submit} className="space-y-5">
                <Input
                  label="Компанийн төлөх дүн (нэг хариултанд)"
                  type="number"
                  min={1}
                  step={10}
                  value={cost}
                  onChange={(e) => {
                    setCost(e.target.value);
                    setSaved(false);
                  }}
                  hint="Компани нэг судалгааны хариулт бүрд төлөх ₮"
                />
                <Input
                  label="Хэрэглэгчид олгох дүн"
                  type="number"
                  min={1}
                  step={10}
                  value={reward}
                  onChange={(e) => {
                    setReward(e.target.value);
                    setSaved(false);
                  }}
                  hint="Судалгаа бөглөсөн хэрэглэгчийн хэтэвч рүү орох ₮"
                />

                <div className="rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] p-4 text-xs">
                  <div className="mb-1 font-semibold text-[var(--color-accent)]">
                    Платформын шимтгэл (авто тооцоолсон)
                  </div>
                  <div className="font-mono text-lg font-bold text-[var(--color-text-primary)]">
                    {formatTugrik(commission)}
                  </div>
                  <div className="mt-1 text-[var(--color-text-secondary)]">
                    Компанийн төлбөр – Хэрэглэгчийн урамшуулал
                  </div>
                </div>

                {error && (
                  <div className="flex items-start gap-2 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]">
                    <AlertCircle size={14} className="mt-0.5 shrink-0" />
                    <span>{error}</span>
                  </div>
                )}
                {saved && !error && (
                  <div className="rounded-lg border border-[var(--color-success)]/40 bg-[color-mix(in_oklab,var(--color-success)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-success)]">
                    Хадгаллаа
                  </div>
                )}

                <Button
                  type="submit"
                  disabled={loading || settings === null}
                  leftIcon={<Save size={14} />}
                >
                  {loading ? "Хадгалж байна..." : "Хадгалах"}
                </Button>
              </form>
            )}
          </CardBody>
        </Card>

        <Card>
          <CardHeader title="Хэрхэн ажилладаг вэ?" />
          <CardBody className="space-y-4 text-sm text-[var(--color-text-secondary)]">
            <div className="flex gap-3">
              <DollarSign
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                Компаниуд <b className="text-[var(--color-text-primary)]">видеогүй</b>
                {" "}судалгаа-кампани үүсгэхэд эдгээр үнийг ашиглана.
              </p>
            </div>
            <div className="flex gap-3">
              <DollarSign
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                Хэрэглэгч бүр судалгаа бөглөх бүрд{" "}
                <b className="text-[var(--color-text-primary)]">
                  Хэрэглэгчид олгох дүн
                </b>{" "}
                хэтэвчиндээ авна.
              </p>
            </div>
            <div className="flex gap-3">
              <DollarSign
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                Хоёр дүнгийн зөрүү нь платформын{" "}
                <b className="text-[var(--color-text-primary)]">шимтгэл</b>.
              </p>
            </div>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
