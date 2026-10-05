import { formatDuration } from "./utils";

/** Allowed video campaign length, in seconds. */
export const MIN_VIDEO_SECONDS = 5;
export const MAX_VIDEO_SECONDS = 180;

export type VideoLengthStatus = "idle" | "reading" | "ready" | "error";

/**
 * Reads a video file's length in whole seconds from its metadata, entirely
 * in the browser (no upload needed). Rounds DOWN so we never claim a video
 * is longer than it really is — the viewer app's full-watch gate unlocks at
 * `durationSeconds`, which must always be reachable.
 *
 * Rejects when the browser can't decode the file or reports no finite
 * duration. `createVideo` is injectable for tests.
 */
export function readVideoDuration(
  file: Blob,
  createVideo: () => HTMLVideoElement = () => document.createElement("video"),
): Promise<number> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const video = createVideo();
    const cleanup = () => {
      video.onloadedmetadata = null;
      video.onerror = null;
      video.removeAttribute("src");
      URL.revokeObjectURL(url);
    };
    video.preload = "metadata";
    video.muted = true;
    video.onloadedmetadata = () => {
      const seconds = video.duration;
      cleanup();
      if (Number.isFinite(seconds) && seconds > 0) {
        resolve(Math.floor(seconds));
      } else {
        reject(new Error("Video duration is unknown"));
      }
    };
    video.onerror = () => {
      cleanup();
      reject(new Error("Video could not be read"));
    };
    video.src = url;
  });
}

export function isVideoLengthAllowed(seconds: number | null): boolean {
  return (
    seconds !== null &&
    seconds >= MIN_VIDEO_SECONDS &&
    seconds <= MAX_VIDEO_SECONDS
  );
}

/** Status line shown under the file picker in the campaign wizard. */
export function describeVideoLength(
  status: VideoLengthStatus,
  seconds: number | null,
): { tone: "muted" | "busy" | "ok" | "error"; text: string } {
  switch (status) {
    case "idle":
      return {
        tone: "muted",
        text: "Видеоны уртыг файлаас автоматаар тодорхойлно",
      };
    case "reading":
      return { tone: "busy", text: "Видеоны уртыг уншиж байна..." };
    case "error":
      return {
        tone: "error",
        text: "Видеоны уртыг уншиж чадсангүй. Өөр MP4 файл сонгоно уу.",
      };
    case "ready":
      if (seconds === null) {
        return { tone: "error", text: "Видеоны урт тодорхойгүй байна" };
      }
      return isVideoLengthAllowed(seconds)
        ? { tone: "ok", text: `Урт: ${formatDuration(seconds)}` }
        : {
            tone: "error",
            text:
              `Урт: ${formatDuration(seconds)} — видео ` +
              `${formatDuration(MIN_VIDEO_SECONDS)}–` +
              `${formatDuration(MAX_VIDEO_SECONDS)} урттай байх ёстой`,
          };
  }
}
