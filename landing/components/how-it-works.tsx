import { UserRound, Play, MessageCircle, Sparkles } from "lucide-react";
import { STEPS } from "@/lib/content";
const icons = [UserRound, Play, MessageCircle, Sparkles];
export function HowItWorks() {
  return (
    <section id="how" className="section container">
      <div className="section-heading">
        <div>
          <p className="eyebrow">ЭХЛЭХЭД АМАРХАН</p>
          <h2>
            Хэдхэн минут.
            <br />
            <span className="muted-heading">Бодит санал.</span>
          </h2>
        </div>
        <p>
          Танд тохирсон танилцуулгаас эхлээд
          <br />
          таны бодлыг сонсох хүртэл.
        </p>
      </div>
      <ol className="steps">
        {STEPS.map((s, i) => {
          const Icon = icons[i];
          return (
            <li key={s.title}>
              <div className="step-top">
                <Icon size={23} />
                <span>0{i + 1}</span>
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
