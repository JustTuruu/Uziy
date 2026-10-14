import { ArrowUpRight, Check, ChartNoAxesCombined } from "lucide-react";
import { COMPANIES } from "@/lib/content";
export function ForCompanies({ companyPanelUrl }: { companyPanelUrl: string }) {
  return (
    <section id="companies" className="section container">
      <div className="company-panel">
        <div>
          <p className="eyebrow">UZIY / БИЗНЕС</p>
          <h2>
            Зөв хүмүүст хүр.
            <br />
            <span>Бодит саналыг сонс.</span>
          </h2>
          <p className="company-description">{COMPANIES.text}</p>
          <ul>
            {COMPANIES.points.map((p) => (
              <li key={p}>
                <Check size={17} />
                {p}
              </li>
            ))}
          </ul>
          <a className="button button-lime" href={companyPanelUrl}>
            Судалгаа эхлүүлэх <ArrowUpRight size={18} />
          </a>
        </div>
        <div className="business-visual">
          <div className="report-heading">
            <span className="report-icon">
              <ChartNoAxesCombined size={24} />
            </span>
            <span>
              Санал бүрийг
              <br />
              <b>шийдвэр болго.</b>
            </span>
          </div>
          <div className="report-card">
            <div className="report-title">
              <b>Хэрэглэгчийн сонголт</b>
              <span>ЖИШЭЭ</span>
            </div>
            <p>Сонголтод юу нөлөөлдөг вэ?</p>
            {[
              { label: "Чанар", width: 78 },
              { label: "Үнэ", width: 54 },
              { label: "Савлагаа", width: 32 },
            ].map((b) => (
              <div className="report-row" key={b.label}>
                <span>{b.label}</span>
                <div>
                  <i style={{ width: `${b.width}%` }} />
                </div>
              </div>
            ))}
            <div className="report-footer">
              <span className="status-dot" /> Нэгтгэсэн хариулт. Илүү тодорхой
              ойлголт.
            </div>
          </div>
          <p className="report-caption">Үр дүнгийн самбарын жишээ дүрслэл</p>
        </div>
      </div>
    </section>
  );
}
