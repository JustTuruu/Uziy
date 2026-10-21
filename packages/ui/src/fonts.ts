import { Rubik } from "next/font/google";

/**
 * Console UI font for both panels (owner, 2026-10-21: softer and easier on the
 * eyes). Rubik has rounded corners, a tall x-height, tabular figures for money
 * columns, and covers Mongolian Ө/Ү (cyrillic-ext) and the ₮ sign (latin-ext).
 * next/font self-hosts it, so the browser never calls Google. Defined once
 * here (a "font definitions file") so both apps share one instance;
 * theme-light.css puts `--font-rubik` first in `--font-sans`.
 * Put `consoleFont.variable` on the <html> element.
 */
export const consoleFont = Rubik({
  subsets: ["latin", "latin-ext", "cyrillic", "cyrillic-ext"],
  variable: "--font-rubik",
  display: "swap",
});
