"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AlertCircle, Percent, Save, ShieldCheck, Wallet } from "lucide-react";
import { Button, Card, CardBody, CardHeader, NumericInput, PageHeader } from "@uziy/ui";
import {
  adminApi,
  ApiError,
  auth,
  platformSettingsApi,
  type PlatformSettings,
} from "@/lib/api";
import {
  MAX_COMMISSION_PERCENT,
  MIN_COMMISSION_PERCENT,
  computeCampaignPricing,
  validateCommissionSettings,
} from "@/lib/pricing";
import {
  formatNumber,
  formatTugrik,
  parseIntInput,
  relativeTime,
} from "@/lib/utils";

const EXAMPLE_BUDGET = 1_000_000;
const EXAMPLE_VIEWERS = 1_000;

export default function CommissionSettingsPage() {
  const router = useRouter();

  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [percentText, setPercentText] = useState("");
  const [minRewardText, setMinRewardText] = useState("");
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
        setPercentText(String(s.commissionPercent));
        setMinRewardText(String(s.minRewardPerViewer));
      })
      .catch((e) => {
        setError(e instanceof Error ? e.message : "Алдаа гарлаа");
      });
  }, [router]);

  const percent = parseIntInput(percentText);
  const minReward = parseIntInput(minRewardText);
  const validationError = validateCommissionSettings(percent, minReward);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSaved(false);
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);
    try {
      const next = await adminApi.updateSettings({
        commissionPercent: percent,
        minRewardPerViewer: minReward,
      });
      setSettings(next);
      setPercentText(String(next.commissionPercent));
      setMinRewardText(String(next.minRewardPerViewer));
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

  const example =
    validationError === null
      ? computeCampaignPricing({
          budget: EXAMPLE_BUDGET,
          mode: "VIEWERS",
          targetViewers: EXAMPLE_VIEWERS,
          commissionPercent: percent,
          minRewardPerViewer: minReward,
        })
      : null;

  return (
    <>
      <PageHeader
        title="Шимтгэл ба урамшуулал"
        description="Аян бүрийн төсвөөс платформын авах шимтгэл болон үзэгчид олгох хамгийн бага урамшууллыг тохируулна"
      />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="Одоогийн тохиргоо"
            description={
              settings
                ? `Хадгалсны дараа шинээр үүсэх аянуудад мөрдөгдөнө · Сүүлд шинэчилсэн: ${relativeTime(settings.updatedAt)}`
                : "Хадгалсны дараа шинээр үүсэх аянуудад мөрдөгдөнө"
            }
          />
          <CardBody>
            {settings === null && !error ? (
              <div className="animate-pulse text-sm text-[var(--color-text-muted)]">
                Ачаалж байна...
              </div>
            ) : (
              <form onSubmit={submit} noValidate className="space-y-5">
                <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <NumericInput
                    label="Платформын шимтгэл (%)"
                    maxLength={2}
                    value={percentText}
                    onValueChange={(text) => {
                      setPercentText(text);
                      setSaved(false);
                    }}
                    hint={`${MIN_COMMISSION_PERCENT}–${MAX_COMMISSION_PERCENT}% хооронд. Аяны төсвөөс хасагдана.`}
                  />
                  <NumericInput
                    label="Нэг үзэгчид олгох хамгийн бага урамшуулал (₮)"
                    maxLength={7}
                    value={minRewardText}
                    onValueChange={(text) => {
                      setMinRewardText(text);
                      setSaved(false);
                    }}
                    hint="Үүнээс бага урамшуулалтай аян үүсгэх боломжгүй"
                  />
                </div>

                <div className="rounded-xl border border-[color-mix(in_oklab,var(--color-accent)_35%,transparent)] bg-[color-mix(in_oklab,var(--color-accent)_10%,transparent)] p-4 text-xs">
                  <div className="mb-1 font-semibold text-[var(--color-accent)]">
                    Жишээ
                  </div>
                  {example ? (
                    <div className="text-sm text-[var(--color-text-primary)]">
                      {formatTugrik(EXAMPLE_BUDGET)} төсөв,{" "}
                      {formatNumber(EXAMPLE_VIEWERS)} үзэгч → үзэгч бүр{" "}
                      <b className="font-mono">
                        {formatTugrik(example.rewardPerViewer)}
                      </b>
                      , платформ{" "}
                      <b className="font-mono">
                        {formatTugrik(example.commissionTotal)}
                      </b>
                    </div>
                  ) : (
                    <div className="text-[var(--color-text-secondary)]">
                      Зөв утга оруулахад жишээ тооцоо энд харагдана.
                    </div>
                  )}
                </div>

                {error && (
                  <div
                    role="alert"
                    className="flex items-start gap-2 rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]"
                  >
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
              <Wallet
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                Компани аяндаа{" "}
                <b className="text-[var(--color-text-primary)]">нийт төсөв</b>{" "}
                оруулаад хүрэх үзэгчийн тоо эсвэл нэг үзэгчид олгох урамшууллаа
                сонгоно. Төлбөрийг аян тус бүрээр төлнө.
              </p>
            </div>
            <div className="flex gap-3">
              <Percent
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                Нэг үзэгчид ногдох дүнгээс{" "}
                <b className="text-[var(--color-text-primary)]">шимтгэл</b>{" "}
                хасагдаж, үлдсэн нь үзэгчийн хэтэвчинд орно.
              </p>
            </div>
            <div className="flex gap-3">
              <ShieldCheck
                size={16}
                className="mt-0.5 shrink-0 text-[var(--color-primary)]"
              />
              <p>
                <b className="text-[var(--color-text-primary)]">
                  Хамгийн бага урамшуулал
                </b>{" "}
                нь үзэгчдэд хэт бага урамшуулалтай аян үүсэхээс сэргийлнэ. Өмнө
                үүссэн аянууд үүсэх үеийнхээ шимтгэлээр үргэлжилнэ.
              </p>
            </div>
          </CardBody>
        </Card>
      </div>
    </>
  );
}
