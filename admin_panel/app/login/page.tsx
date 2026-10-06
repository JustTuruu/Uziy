"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Input } from "@uziy/ui";
import { ApiError, auth, authApi } from "@/lib/api";

const ROLE = "ADMIN" as const;

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (phone.length < 8 || password.length < 6) {
      setError("Утасны дугаар болон нууц үгээ шалгана уу");
      return;
    }
    setLoading(true);
    try {
      const res = await authApi.login({ phoneNumber: phone, password });
      if (res.user.role !== ROLE) {
        setError("Энэ данс админ эрхгүй байна");
        setLoading(false);
        return;
      }
      auth.setToken(res.token);
      auth.setUser(res.user);
      router.push("/");
    } catch (e) {
      console.error("[login] request failed:", e);
      if (e instanceof ApiError && e.status === 401) {
        setError("Утас эсвэл нууц үг буруу байна");
      } else if (e instanceof ApiError) {
        setError(e.message || "Алдаа гарлаа");
      } else {
        const detail = e instanceof Error ? e.message : String(e);
        setError(`Сервертэй холбогдож чадсангүй: ${detail}`);
      }
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen">
      {/* Left: brand */}
      <div className="relative hidden w-1/2 flex-col justify-between overflow-hidden border-r border-[var(--color-divider)] bg-[var(--color-surface)] p-12 lg:flex">
        {/* faint grid + gold glow */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-60 [background-image:linear-gradient(var(--color-divider)_1px,transparent_1px),linear-gradient(90deg,var(--color-divider)_1px,transparent_1px)] [background-size:48px_48px] [mask-image:radial-gradient(ellipse_at_30%_40%,black,transparent_70%)]"
        />
        <div
          aria-hidden
          className="pointer-events-none absolute -bottom-32 -left-24 h-96 w-96 rounded-full bg-[var(--color-primary)] opacity-[0.07] blur-3xl"
        />
        <div className="relative flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-white shadow-[0_0_0_1px_rgb(255_255_255/0.1)]">
            <Image
              src="/logo.png"
              alt="Uziy"
              width={44}
              height={44}
              priority
              className="h-9 w-9 object-contain"
            />
          </div>
          <div className="text-xl font-extrabold tracking-tight">Uziy</div>
        </div>

        <div className="relative">
          <h2 className="max-w-md text-3xl font-semibold leading-tight tracking-tight">
            Зорилтот үзэгчдэдээ хүрч,{" "}
            <span className="text-[var(--color-primary)]">жинхэнэ дата</span>{" "}
            цуглуул.
          </h2>
          <p className="mt-4 max-w-md text-sm text-[var(--color-text-secondary)]">
            Rewarded video сурталчилгааны платформ. Компаниуд нас, хүйс,
            байршлаар нарийн зорилтот хэрэглэгчдэдээ видеог хүргэж, судалгааны
            үр дүн бодит хугацаанд харна.
          </p>
        </div>

        <div className="relative flex gap-6 text-xs text-[var(--color-text-muted)]">
          <span>© 2026 Uziy</span>
          <span>support@uziy.mn</span>
        </div>
      </div>

      {/* Right: form */}
      <div className="flex w-full items-center justify-center px-6 py-12 lg:w-1/2">
        <div className="w-full max-w-sm">
          <h1 className="text-2xl font-semibold tracking-tight">
            Супер Админ самбарт нэвтрэх
          </h1>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
            Зөвхөн платформын админуудад
          </p>

          <form onSubmit={submit} noValidate className="mt-6 space-y-4">
            <Input
              label="Утасны дугаар"
              inputMode="numeric"
              maxLength={8}
              placeholder="99112233"
              value={phone}
              onChange={(e) =>
                setPhone(e.target.value.replace(/\D/g, "").slice(0, 8))
              }
            />
            <Input
              label="Нууц үг"
              type="password"
              placeholder="•••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            {error && (
              <div className="rounded-lg border border-[var(--color-danger)]/40 bg-[color-mix(in_oklab,var(--color-danger)_10%,transparent)] px-3 py-2 text-xs text-[var(--color-danger)]">
                {error}
              </div>
            )}
            <Button
              type="submit"
              disabled={loading}
              className="w-full"
              size="lg"
            >
              {loading ? "Нэвтэрч байна..." : "Нэвтрэх"}
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
}
