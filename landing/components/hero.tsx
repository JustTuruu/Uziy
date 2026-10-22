import { ArrowDown, Check } from "lucide-react";
import { HERO } from "@/lib/content";
import type { SiteLinks } from "@/lib/links";
import { revealOrder } from "@/lib/reveal";
import { PhoneDemo } from "./phone-demo";

/** The headline runs across the whole width so it holds two lines; the copy and the live phone share the row below. */
export function Hero({ links }: { links: SiteLinks }) {
  const available = Boolean(links.appStore || links.playStore);
  return (
    <section id="top" className="hero container">
      <h1 className="hero-title" data-reveal style={revealOrder(0)}>
        {HERO.title}
      </h1>
      <div className="hero-copy">
        <p className="hero-description" data-reveal style={revealOrder(1)}>
          {HERO.subtitle}
        </p>
        <div className="hero-actions" data-reveal style={revealOrder(2)}>
          <a className="button button-primary" href="#download">
            {available ? HERO.ctaReady : HERO.ctaSoon}
            {/* It jumps to the download section on this page, so it points down, not out. */}
            <ArrowDown size={19} aria-hidden />
          </a>
          <a className="text-link" href="#how">
            {HERO.secondary} <ArrowDown size={16} aria-hidden />
          </a>
        </div>
        <ul className="hero-facts" data-reveal style={revealOrder(3)}>
          {HERO.facts.map((fact) => (
            <li key={fact}>
              <Check size={16} aria-hidden /> {fact}
            </li>
          ))}
        </ul>
      </div>
      {/* data-ui: a cropped piece of the app, so it keeps its own frame, lines and shadow. */}
      <div className="hero-stage" data-ui data-reveal style={revealOrder(2)}>
        <div className="stage-orbit" aria-hidden />
        <PhoneDemo />
      </div>
    </section>
  );
}
