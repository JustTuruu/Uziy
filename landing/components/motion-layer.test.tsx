import { render } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { MOTION_ATTRIBUTE, REVEALED_CLASS, revealOrder } from "@/lib/reveal";
import { MotionLayer, revealIntersecting } from "./motion-layer";

type Callback = (entries: IntersectionObserverEntry[], observer: IntersectionObserver) => void;

/** A stand-in IntersectionObserver that lets the test say which elements are on screen. */
function installObserver() {
  const watched: Element[] = [];
  let callback: Callback = () => {};
  const observer = {
    observe: (el: Element) => watched.push(el),
    unobserve: vi.fn(),
    disconnect: vi.fn(),
  } as unknown as IntersectionObserver;
  vi.stubGlobal(
    "IntersectionObserver",
    vi.fn(function (cb: Callback) {
      callback = cb;
      return observer;
    }),
  );
  const show = (el: Element) =>
    callback([{ target: el, isIntersecting: true } as unknown as IntersectionObserverEntry], observer);
  return { watched, observer, show };
}

function stubReducedMotion(reduce: boolean) {
  vi.stubGlobal("matchMedia", (query: string) => ({ matches: reduce && query.includes("reduce") }));
}

afterEach(() => {
  vi.unstubAllGlobals();
  document.documentElement.removeAttribute(MOTION_ATTRIBUTE);
});

describe("MotionLayer", () => {
  it("switches motion on and reveals a part once it scrolls into view", () => {
    stubReducedMotion(false);
    const { watched, observer, show } = installObserver();
    render(
      <>
        <h2 data-reveal>Гарчиг</h2>
        <p data-reveal>Текст</p>
        <MotionLayer />
      </>,
    );
    expect(document.documentElement).toHaveAttribute(MOTION_ATTRIBUTE, "on");
    expect(watched).toHaveLength(2);

    show(watched[0]);
    expect(watched[0]).toHaveClass(REVEALED_CLASS);
    expect(watched[1]).not.toHaveClass(REVEALED_CLASS);
    expect(observer.unobserve).toHaveBeenCalledWith(watched[0]);
  });

  it("leaves the page finished and still for reduced-motion visitors", () => {
    stubReducedMotion(true);
    const { watched } = installObserver();
    render(
      <>
        <p data-reveal>Текст</p>
        <MotionLayer />
      </>,
    );
    expect(document.documentElement).not.toHaveAttribute(MOTION_ATTRIBUTE);
    expect(watched).toHaveLength(0);
  });

  it("turns motion off again when it unmounts", () => {
    stubReducedMotion(false);
    installObserver();
    const { unmount } = render(<MotionLayer />);
    unmount();
    expect(document.documentElement).not.toHaveAttribute(MOTION_ATTRIBUTE);
  });
});

describe("revealIntersecting", () => {
  it("ignores parts that are still off screen", () => {
    const el = document.createElement("p");
    const observer = { unobserve: vi.fn() } as unknown as IntersectionObserver;
    revealIntersecting([{ target: el, isIntersecting: false } as unknown as IntersectionObserverEntry], observer);
    expect(el).not.toHaveClass(REVEALED_CLASS);
    expect(observer.unobserve).not.toHaveBeenCalled();
  });
});

describe("revealOrder", () => {
  it("passes the order to CSS as a custom property", () => {
    expect(revealOrder(3)).toEqual({ "--reveal-order": 3 });
  });
});
