import { ArrowUpRight, Check, ChartNoAxesCombined, Mail, Phone } from "lucide-react";
import { COMPANIES } from "@/lib/content";
import { revealOrder } from "@/lib/reveal";

function Lines({ text }: { text: string }) {
  return text.split("\n").map((line, i) => (
    <span key={line}>
      {i > 0 && <br />}
      {line}
    </span>
  ));
}

/** `tel:` target of a typed phone number: digits and a leading + only. */
export function telHref(phone: string): string {
  return `tel:${phone.replace(/[^\d+]/g, "")}`;
}

/**
 * For advertisers. Companies cannot sign themselves up (Uziy creates their accounts, 2026-10-22), so the main action
 * is contacting Uziy (email / phone, each only when configured — never a made-up address) and the login is a
 * secondary link for companies that already have an account. With no contact configured the login is all there is.
 */
export function ForCompanies({
  companyPanelUrl,
  contactEmail = null,
  contactPhone = null,
}: {
  companyPanelUrl: string;
  contactEmail?: string | null;
  contactPhone?: string | null;
}) {
  const hasContact = Boolean(contactEmail || contactPhone);
  const { report } = COMPANIES;
  return (
    <section id="companies" className="section container">
      <div className="company-panel">
        <div>
          <h2 data-reveal>{COMPANIES.title}</h2>
          <p className="company-description" data-reveal style={revealOrder(1)}>
            {COMPANIES.text}
          </p>
          <ul data-reveal style={revealOrder(2)}>
            {COMPANIES.points.map((p) => (
              <li key={p}>
                <Check size={17} aria-hidden />
                {p}
              </li>
            ))}
          </ul>
          {hasContact ? (
            <div className="company-contacts">
              <p className="company-contacts-title">{COMPANIES.contactTitle}</p>
              <div className="company-actions">
                {contactEmail && (
                  <a className="button button-lime" href={`mailto:${contactEmail}`}>
                    <Mail size={18} aria-hidden /> {contactEmail}
                  </a>
                )}
                {contactPhone && (
                  <a className="button button-lime" href={telHref(contactPhone)}>
                    <Phone size={18} aria-hidden /> {contactPhone}
                  </a>
                )}
              </div>
              <p className="company-note">
                {COMPANIES.accountNote}{" "}
                <a className="company-login" href={companyPanelUrl}>
                  {COMPANIES.login} <ArrowUpRight size={15} aria-hidden />
                </a>
              </p>
            </div>
          ) : (
            <a className="button button-lime" href={companyPanelUrl}>
              {COMPANIES.cta} <ArrowUpRight size={18} aria-hidden />
            </a>
          )}
        </div>
        {/* data-ui: a cropped piece of the company panel, so it keeps its own lines. */}
        <div className="business-visual" aria-hidden data-ui data-reveal style={revealOrder(2)}>
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
