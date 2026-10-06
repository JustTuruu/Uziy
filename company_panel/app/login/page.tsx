"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Input } from "@uziy/ui";
import { ApiError, auth, authApi } from "@/lib/api";

// This console only admits one role; the other console lives in its own app.
const ROLE = "COMPANY" as const;

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
        setError("Энэ данс компани эрхгүй байна");
        setLoading(false);
        return;
      }
      auth.setToken(res.token);
      auth.setUser(res.user);
      router.push("/");
    } catch (e) {
      // Log the real error to the browser console so it's easy to
      // diagnose in DevTools (network error, CORS block, etc.).
      console.error("[login] request failed:", e);
      if (e instanceof ApiError && e.status === 401) {
        setError("Утас эсвэл нууц үг буруу байна");
      } else if (e instanceof ApiError) {
        setError(e.message || "Алдаа гарлаа");
      } else {
        // Surface the real message rather than a generic string so the
        // user can see whether it's DNS, CORS, refused connection, etc.
        const detail =
          e instanceof Error ? e.message : String(e);
        setError(`Сервертэй холбогдож чадсангүй: ${detail}`);
      }
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen">
      {/* Left: brand */}
      <div className="hidden w-1/2 flex-col justify-between bg-[var(--color-surface)] p-12 lg:flex">
        <div className="flex items-center gap-3">
          <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-white/95">
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

        <div>
          <h2 className="max-w-md text-3xl font-extrabold leading-tight tracking-tight">
            Зорилтот үзэгчдэдээ хүрч,{" "}
            <span className="text-[var(--color-primary)]">
              жинхэнэ дата
            </span>{" "}
            цуглуул.
          </h2>
          <p className="mt-4 max-w-md text-sm text-[var(--color-text-secondary)]">
            Rewarded video сурталчилгааны платформ. Компаниуд нас, хүйс,
            байршлаар нарийн зорилтот хэрэглэгчдэдээ видеог хүргэж, судалгааны
            үр дүн бодит хугацаанд харна.
          </p>
        </div>

        <div className="flex gap-6 text-xs text-[var(--color-text-secondary)]">
          <span>© 2026 Uziy</span>
          <span>support@uziy.mn</span>
        </div>
      </div>

      {/* Right: form */}
      <div className="flex w-full items-center justify-center px-6 py-12 lg:w-1/2">
        <div className="w-full max-w-sm">
          <h1 className="text-2xl font-extrabold tracking-tight">
            Компанийн самбарт нэвтрэх
          </h1>
          <p className="mt-1 text-sm text-[var(--color-text-secondary)]">
            Компанийн дансаараа нэвтэрнэ үү
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

          <div className="mt-6 text-center text-xs text-[var(--color-text-muted)]">
            Компаниар бүртгүүлэх бол{" "}
            <a
              href="mailto:sales@uziy.mn"
              className="text-[var(--color-primary)] hover:underline"
            >
              sales@uziy.mn
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
