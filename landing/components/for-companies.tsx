import { ArrowUpRight, Check, ChartNoAxesCombined, Mail } from "lucide-react";
import { COMPANIES } from "@/lib/content";

function Lines({ text }: { text: string }) {
  return text.split("\n").map((line, i) => (
    <span key={line}>
      {i > 0 && <br />}
      {line}
    </span>
  ));
}

/**
 * For advertisers. Companies cannot sign themselves up (Uziy creates their accounts, 2026-10-22), so the button
 * opens the company panel's login and a contact link appears only when an address is configured.
 */
export function ForCompanies({
  companyPanelUrl,
  contactEmail = null,
}: {
  companyPanelUrl: string;
  contactEmail?: string | null;
}) {
  const { report } = COMPANIES;
  return (
    <section id="companies" className="section container">
      <div className="company-panel">
        <div>
          <h2>
            {COMPANIES.title}
            <br />
            <span>{COMPANIES.accent}</span>
          </h2>
          <p className="company-description">{COMPANIES.text}</p>
          <ul>
            {COMPANIES.points.map((p) => (
              <li key={p}>
                <Check size={17} aria-hidden />
                {p}
              </li>
            ))}
          </ul>
          <div className="company-actions">
            <a className="button button-lime" href={companyPanelUrl}>
              {COMPANIES.cta} <ArrowUpRight size={18} aria-hidden />
            </a>
            {contactEmail && (
              <a className="company-contact" href={`mailto:${contactEmail}`}>
                <Mail size={16} aria-hidden /> {COMPANIES.contact}
              </a>
            )}
          </div>
          <p className="company-note">{COMPANIES.accountNote}</p>
        </div>
        <div className="business-visual" aria-hidden>
          <div className="report-heading">
            <span className="report-icon">
              <ChartNoAxesCombined size={24} />
            </span>
            <b>
              <Lines text={report.heading} />
            </b>
          </div>
          <div className="report-card">
            <div className="report-title">
              <b>{report.title}</b>
              <span>{report.badge}</span>
            </div>
            {report.rows.map((row) => (
              <div className="report-row" key={row.label}>
                <span>{row.label}</span>
                <div>
                  <i style={{ width: `${row.width}%` }} />
                </div>
                <em>{row.width}%</em>
              </div>
            ))}
            <div className="report-footer">
              <span className="status-dot" /> {report.footer}
            </div>
          </div>
          <p className="report-caption">{report.caption}</p>
        </div>
      </div>
    </section>
  );
}
