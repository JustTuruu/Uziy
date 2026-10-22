import { Plus } from "lucide-react";
import { FAQ_HEADING, FAQS } from "@/lib/content";

export function FaqList() {
  return (
    <section id="faq" className="section container faq-layout">
      <div>
        <h2>{FAQ_HEADING.title}</h2>
        <p className="section-description">{FAQ_HEADING.lead}</p>
      </div>
      <div className="faq-list">
        {FAQS.map((f) => (
          <details key={f.question}>
            <summary>
              <span>{f.question}</span>
              <Plus size={19} aria-hidden />
            </summary>
            <p>{f.answer}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
