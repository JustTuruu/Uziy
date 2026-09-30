import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  MAX_VIDEO_SECONDS,
  MIN_VIDEO_SECONDS,
  describeVideoLength,
  isVideoLengthAllowed,
  readVideoDuration,
} from "./video";

type FakeVideo = {
  preload: string;
  muted: boolean;
  src: string;
  duration: number;
  onloadedmetadata: (() => void) | null;
  onerror: (() => void) | null;
  removeAttribute: (name: string) => void;
};

function fakeVideo(): FakeVideo {
  return {
    preload: "",
    muted: false,
    src: "",
    duration: Number.NaN,
    onloadedmetadata: null,
    onerror: null,
    removeAttribute(name) {
      if (name === "src") this.src = "";
    },
  };
}

const originalCreate = URL.createObjectURL;
const originalRevoke = URL.revokeObjectURL;

beforeEach(() => {
  URL.createObjectURL = vi.fn(() => "blob:video-1");
  URL.revokeObjectURL = vi.fn();
});

afterEach(() => {
  URL.createObjectURL = originalCreate;
  URL.revokeObjectURL = originalRevoke;
});

function start(video: FakeVideo) {
  return readVideoDuration(
    new Blob(["x"], { type: "video/mp4" }),
    () => video as unknown as HTMLVideoElement,
  );
}

describe("readVideoDuration", () => {
  it("loads only metadata from an object URL of the file", () => {
    const video = fakeVideo();
    void start(video).catch(() => {});
    expect(video.src).toBe("blob:video-1");
    expect(video.preload).toBe("metadata");
    expect(video.muted).toBe(true);
  });

  it("resolves whole seconds, rounded down", async () => {
    const video = fakeVideo();
    const p = start(video);
    video.duration = 44.97;
    video.onloadedmetadata?.();
    await expect(p).resolves.toBe(44);
  });

  it("revokes the object URL and detaches the source once read", async () => {
    const video = fakeVideo();
    const p = start(video);
    video.duration = 30;
    video.onloadedmetadata?.();
    await p;
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:video-1");
    expect(video.src).toBe("");
    expect(video.onloadedmetadata).toBeNull();
  });

  it("rejects when the reported duration is not finite (e.g. a live stream)", async () => {
    const video = fakeVideo();
    const p = start(video);
    video.duration = Number.POSITIVE_INFINITY;
    video.onloadedmetadata?.();
    await expect(p).rejects.toThrow();
  });

  it("rejects when the reported duration is zero", async () => {
    const video = fakeVideo();
    const p = start(video);
    video.duration = 0;
    video.onloadedmetadata?.();
    await expect(p).rejects.toThrow();
  });

  it("rejects and cleans up when the browser cannot decode the file", async () => {
    const video = fakeVideo();
    const p = start(video);
    video.onerror?.();
    await expect(p).rejects.toThrow();
    expect(URL.revokeObjectURL).toHaveBeenCalledWith("blob:video-1");
  });
});

describe("isVideoLengthAllowed", () => {
  it("accepts lengths inside the allowed range, inclusive", () => {
    expect(isVideoLengthAllowed(MIN_VIDEO_SECONDS)).toBe(true);
    expect(isVideoLengthAllowed(45)).toBe(true);
    expect(isVideoLengthAllowed(MAX_VIDEO_SECONDS)).toBe(true);
  });

  it("rejects missing, too short and too long lengths", () => {
    expect(isVideoLengthAllowed(null)).toBe(false);
    expect(isVideoLengthAllowed(MIN_VIDEO_SECONDS - 1)).toBe(false);
    expect(isVideoLengthAllowed(MAX_VIDEO_SECONDS + 1)).toBe(false);
  });
});

describe("describeVideoLength", () => {
  it("explains the automatic length before a file is picked", () => {
    expect(describeVideoLength("idle", null)).toEqual({
      tone: "muted",
      text: "Видеоны уртыг файлаас автоматаар тодорхойлно",
    });
  });

  it("shows progress while reading", () => {
    expect(describeVideoLength("reading", null).tone).toBe("busy");
  });

  it("shows the detected length as m:ss", () => {
    expect(describeVideoLength("ready", 45)).toEqual({
      tone: "ok",
      text: "Урт: 0:45",
    });
  });

  it("flags a length outside the allowed range", () => {
    const d = describeVideoLength("ready", 200);
    expect(d.tone).toBe("error");
    expect(d.text).toContain("3:20");
    expect(d.text).toContain("0:05–3:00");
  });

  it("asks for another file when the video can't be read", () => {
    expect(describeVideoLength("error", null).tone).toBe("error");
    expect(describeVideoLength("ready", null).tone).toBe("error");
  });
});
