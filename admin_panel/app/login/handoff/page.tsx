"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { ButtonLink, Card, CardBody } from "@uziy/ui";
import { ApiError, auth, authApi } from "@/lib/api";
import { HANDOFF_EXPIRED, SIGN_IN_URL, codeFromHash } from "@/lib/handoff";

/** Where the handoff lands: strip the code from the address bar, spend it, and open the dashboard. */
export default function HandoffPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  // Spend the code once, even when React runs the effect twice in development.
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    const code = codeFromHash(window.location.hash);
    // The code must not stay in the address bar or the history.
    window.history.replaceState(null, "", window.location.pathname);
    const session = code ? authApi.redeemHandoff(code) : Promise.reject(new ApiError(HANDOFF_EXPIRED, 400, null));
    session
      .then((res) => {
        auth.setToken(res.token);
        auth.setUser(res.user);
        router.replace("/");
      })
      .catch((e: unknown) => setError(e instanceof ApiError ? e.message : HANDOFF_EXPIRED));
  }, [router]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-[var(--color-background)] px-6">
      <Card className="w-full max-w-sm">
        <CardBody className="space-y-4 py-8 text-center">
          {error ? (
            <>
              <p role="alert" className="text-sm text-[var(--color-text-primary)]">
                {error}
              </p>
              <ButtonLink href={SIGN_IN_URL} className="w-full">
                Дахин нэвтрэх
              </ButtonLink>
            </>
          ) : (
            <p className="animate-pulse text-sm text-[var(--color-text-secondary)]">Нэвтэрч байна...</p>
          )}
        </CardBody>
      </Card>
    </div>
  );
}
