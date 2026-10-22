import { FAQ_HEADING, FAQS } from "@/lib/content";
import { revealOrder } from "@/lib/reveal";

export function FaqList() {
  return (
    <section id="faq" className="section container faq-layout">
      <div>
        <h2 data-reveal>{FAQ_HEADING.title}</h2>
        <p className="section-description" data-reveal style={revealOrder(1)}>
          {FAQ_HEADING.lead}
        </p>
      </div>
      <div className="faq-list">
        {FAQS.map((f, i) => (
          <details key={f.question} data-reveal style={revealOrder(i)}>
            <summary>{f.question}</summary>
            <p>{f.answer}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
