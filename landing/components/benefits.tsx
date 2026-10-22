import { ShieldCheck, Check } from "lucide-react";
import { BENEFITS, BENEFITS_HEADING, PRIVACY } from "@/lib/content";
import { revealOrder } from "@/lib/reveal";

/** Why Uziy: three benefits on the left, the concrete privacy promises on the right. */
export function Benefits() {
  return (
    <section id="benefits" className="benefits-section">
      <div className="container benefits-layout">
        <div className="benefits-intro">
          <h2 data-reveal>{BENEFITS_HEADING.title}</h2>
          <p data-reveal style={revealOrder(1)}>
            {BENEFITS_HEADING.lead}
          </p>
          <div className="benefit-list">
            {BENEFITS.map((b, i) => (
              <article key={b.title} data-reveal style={revealOrder(i + 2)}>
                <h3>{b.title}</h3>
                <p>{b.text}</p>
              </article>
            ))}
          </div>
        </div>
        <aside id="privacy" className="privacy-panel" aria-labelledby="privacy-title" data-reveal style={revealOrder(1)}>
          <span className="privacy-icon">
            <ShieldCheck size={26} aria-hidden />
          </span>
          <h2 id="privacy-title">{PRIVACY.title}</h2>
          <ul>
            {PRIVACY.points.map((point) => (
              <li key={point}>
                <Check size={18} aria-hidden />
                <span>{point}</span>
              </li>
            ))}
          </ul>
        </aside>
      </div>
    </section>
  );
}
