import { ArrowDown, ArrowUpRight, Check } from "lucide-react";
import { HERO } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { PhoneDemo } from "./phone-demo";

/** Splits [title] around [accent] so the accent can be coloured; the full title stays one heading. */
export function splitAccent(title: string, accent: string): [string, string, string] {
  const at = title.indexOf(accent);
  if (at < 0) return [title, "", ""];
  return [title.slice(0, at), accent, title.slice(at + accent.length)];
}

export function Hero({ links }: { links: SiteLinks }) {
  const available = Boolean(links.appStore || links.playStore);
  const [before, accent, after] = splitAccent(HERO.title, HERO.accent);
  return (
    <section id="top" className="hero container">
      <div className="hero-copy">
        <h1>
          {before}
          <span>{accent}</span>
          {after}
        </h1>
        <p className="hero-description">{HERO.subtitle}</p>
        <div className="hero-actions">
          <a className="button button-primary" href="#download">
            {available ? HERO.ctaReady : HERO.ctaSoon}
            <ArrowUpRight size={19} aria-hidden />
          </a>
          <a className="text-link" href="#how">
            {HERO.secondary} <ArrowDown size={16} aria-hidden />
          </a>
        </div>
        <ul className="hero-facts">
          {HERO.facts.map((fact) => (
            <li key={fact}>
              <Check size={15} aria-hidden /> {fact}
            </li>
          ))}
        </ul>
      </div>
      <div className="hero-stage">
        <div className="stage-orbit" aria-hidden />
        <PhoneDemo />
      </div>
    </section>
  );
}
