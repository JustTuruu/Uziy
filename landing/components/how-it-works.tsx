import { UserRound, Play, MessageCircle, Ear } from "lucide-react";
import { HOW, STEPS } from "@/lib/content";

/** One icon per step, in the order of STEPS (a test checks the counts match). */
export const STEP_ICONS = [UserRound, Play, MessageCircle, Ear];

export function HowItWorks() {
  return (
    <section id="how" className="section container">
      <div className="section-heading">
        <h2>
          {HOW.title}
          <br />
          <span className="muted-heading">{HOW.accent}</span>
        </h2>
        <p>{HOW.lead}</p>
      </div>
      <ol className="steps">
        {STEPS.map((s, i) => {
          const Icon = STEP_ICONS[i];
          return (
            <li key={s.title}>
              <div className="step-top">
                <Icon size={23} aria-hidden />
                {/* The order matters here, so the step keeps its number. */}
                <span aria-hidden>{i + 1}</span>
              </div>
              <h3>{s.title}</h3>
              <p>{s.text}</p>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
