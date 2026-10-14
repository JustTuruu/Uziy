import { Plus } from "lucide-react";
import { FAQS } from "@/lib/content";
export function FaqList() {
  return (
    <section id="faq" className="section container faq-layout">
      <div>
        <p className="eyebrow">МЭДЭХЭД ИЛҮҮДЭХГҮЙ</p>
        <h2>
          Асуух зүйл
          <br />
          байна уу?
        </h2>
        <p className="section-description">
          Эхлэхээс өмнө мэдэх хэрэгтэй зүйлс.
        </p>
      </div>
      <div className="faq-list">
        {FAQS.map((f, i) => (
          <details key={f.question}>
            <summary>
              <span className="faq-number">0{i + 1}</span>
              <span>{f.question}</span>
              <Plus size={19} />
            </summary>
            <p>{f.answer}</p>
          </details>
        ))}
      </div>
    </section>
  );
}
