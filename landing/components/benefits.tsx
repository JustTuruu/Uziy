import { Target, MessageCircle, Clock3, ShieldCheck, Check } from "lucide-react";
import { BENEFITS, BENEFITS_HEADING, PRIVACY } from "@/lib/content";

const icons = {
  target: Target,
  message: MessageCircle,
  timer: Clock3,
};

/** Why Uziy: three benefits on the left, the concrete privacy promises on the right. */
export function Benefits() {
  return (
    <section id="benefits" className="benefits-section">
      <div className="container benefits-layout">
        <div className="benefits-intro">
          <h2>
            {BENEFITS_HEADING.title}
            <br />
            <span className="muted-heading">{BENEFITS_HEADING.accent}</span>
          </h2>
          <p>{BENEFITS_HEADING.lead}</p>
          <div className="benefit-list">
            {BENEFITS.map((b) => {
              const Icon = icons[b.icon];
              return (
                <article key={b.title}>
                  <span className="benefit-icon">
                    <Icon size={22} aria-hidden />
                  </span>
                  <div>
                    <h3>{b.title}</h3>
                    <p>{b.text}</p>
                  </div>
                </article>
              );
            })}
          </div>
        </div>
        <aside id="privacy" className="privacy-panel" aria-labelledby="privacy-title">
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
