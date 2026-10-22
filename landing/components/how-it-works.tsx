import { HOW, STEPS } from "@/lib/content";
import { revealOrder } from "@/lib/reveal";

/** The four steps as a list set in large type: the order is carried by the <ol> and the wording, not by numbers. */
export function HowItWorks() {
  return (
    <section id="how" className="section container">
      <div className="section-heading">
        <h2 data-reveal>{HOW.title}</h2>
        <p data-reveal style={revealOrder(1)}>
          {HOW.lead}
        </p>
      </div>
      <ol className="steps">
        {STEPS.map((s, i) => (
          <li key={s.title} data-reveal style={revealOrder(i)}>
            <h3>{s.title}</h3>
            <p>{s.text}</p>
          </li>
        ))}
      </ol>
    </section>
  );
}
