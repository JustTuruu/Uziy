"use client";

import { useEffect, useRef, useState } from "react";
import { ImagePlus, Lock, Upload, X } from "lucide-react";
import { Button } from "./button";
import { Card, CardBody, CardHeader } from "./card";
import { cn } from "./cn";

/** What the backend accepts (CampaignImageService): JPG or PNG up to 5 MB. */
export const COVER_IMAGE_TYPES = ["image/jpeg", "image/png"] as const;
export const COVER_IMAGE_MAX_BYTES = 5 * 1024 * 1024;
export const COVER_IMAGE_INVALID = "5 MB хүртэлх JPG эсвэл PNG зураг сонгоно уу";

/** Why [file] cannot be a cover, or null when it can (checked before upload). */
export function coverImageError(file: File): string | null {
  const typeOk = (COVER_IMAGE_TYPES as readonly string[]).includes(file.type);
  const sizeOk = file.size > 0 && file.size <= COVER_IMAGE_MAX_BYTES;
  return typeOk && sizeOk ? null : COVER_IMAGE_INVALID;
}

/**
 * A survey's cover image: preview, pick a file, save or remove. Shared by the
 * admin and company panels — each passes its own upload/remove calls.
 *
 * A picked file is previewed but saved only on 'Зураг хадгалах'; a failed
 * save keeps it so the user can retry. With [lockedNote] the card only shows
 * the current image and the note (e.g. after approval).
 */
export function ImageUploadCard({
  inputId,
  imageUrl,
  onUpload,
  onRemove,
  lockedNote,
  title = "Судалгааны нүүр зураг",
  description = "Аппын судалгааны карт дээр харагдах зураг. JPG, PNG · 5 MB хүртэл · 16:9 харьцаа тохиромжтой.",
  className,
}: {
  inputId: string;
  /** The saved cover, ready to use as <img src>; null when there is none. */
  imageUrl?: string | null;
  onUpload: (file: File) => Promise<void>;
  onRemove: () => Promise<void>;
  lockedNote?: string;
  title?: string;
  description?: string;
  className?: string;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      if (preview) URL.revokeObjectURL(preview);
    };
  }, [preview]);

  function clearSelection() {
    setFile(null);
    setPreview(null);
    if (input.current) input.current.value = "";
  }

  function select(next?: File) {
    setError(null);
    setNotice(null);
    if (!next) return;
    const problem = coverImageError(next);
    if (problem) {
      clearSelection();
      setError(problem);
      return;
    }
    setFile(next);
    setPreview(URL.createObjectURL(next));
  }

  async function save(remove = false) {
    if (busy || (!remove && !file)) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      if (remove) await onRemove();
      else await onUpload(file!);
      clearSelection();
      setNotice(
        remove
          ? "Зургийг арилгалаа"
          : "Зургийг хадгаллаа. Аппын карт дээр харагдана.",
      );
    } catch (e) {
      setError(
        e instanceof Error
          ? e.message
          : "Зураг хадгалж чадсангүй. Дахин оролдоно уу",
      );
    } finally {
      setBusy(false);
    }
  }

  const src = preview || imageUrl || null;
  return (
    <Card className={className}>
      <CardHeader title={title} description={description} />
      <CardBody>
        <div className="grid gap-6 md:grid-cols-[minmax(0,360px)_1fr]">
          <div className="aspect-video overflow-hidden rounded-xl border border-[var(--color-divider)] bg-[var(--color-surface-elevated)]">
            {src ? (
              // Covers are served by our API directly, not through the Next image proxy.
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={src}
                alt="Судалгааны нүүр зургийн урьдчилсан харагдац"
                className="h-full w-full object-cover"
              />
            ) : (
              <div className="flex h-full flex-col items-center justify-center gap-3 text-[var(--color-text-secondary)]">
                <ImagePlus size={30} />
                <span className="text-sm">Зураг оруулаагүй</span>
              </div>
            )}
          </div>
          {lockedNote ? (
            <p className="flex items-start gap-2 self-center text-sm text-[var(--color-text-secondary)]">
              <Lock size={15} className="mt-0.5 shrink-0" />
              {lockedNote}
            </p>
          ) : (
            <div className="flex flex-col items-start justify-center gap-3">
              <label htmlFor={inputId} className="text-sm font-medium">
                Зураг сонгох
              </label>
              <input
                ref={input}
                id={inputId}
                type="file"
                accept={COVER_IMAGE_TYPES.join(",")}
                disabled={busy}
                onChange={(e) => select(e.target.files?.[0])}
                className={cn(
                  "w-full max-w-full text-sm",
                  "file:mr-3 file:cursor-pointer file:rounded-lg file:border-0 file:bg-[var(--color-surface-elevated)] file:px-4 file:py-3 file:text-[var(--color-text-primary)]",
                )}
              />
              {file && (
                <p className="text-xs text-[var(--color-text-secondary)]">
                  Сонгосон зураг хараахан хадгалагдаагүй.
                </p>
              )}
              <div className="flex flex-wrap gap-2">
                {file && (
                  <>
                    <Button
                      disabled={busy}
                      onClick={() => save()}
                      leftIcon={<Upload size={15} />}
                    >
                      {busy ? "Хадгалж байна…" : "Зураг хадгалах"}
                    </Button>
                    <Button
                      variant="secondary"
                      disabled={busy}
                      onClick={clearSelection}
                    >
                      Болих
                    </Button>
                  </>
                )}
                {imageUrl && !file && (
                  <Button
                    variant="secondary"
                    disabled={busy}
                    onClick={() => save(true)}
                    leftIcon={<X size={15} />}
                  >
                    {busy ? "Арилгаж байна…" : "Зураг арилгах"}
                  </Button>
                )}
              </div>
              {error && (
                <p role="alert" className="text-sm text-[var(--color-danger)]">
                  {error}
                </p>
              )}
              {notice && (
                <p role="status" className="text-sm text-[var(--color-success)]">
                  {notice}
                </p>
              )}
            </div>
          )}
        </div>
      </CardBody>
    </Card>
  );
}
