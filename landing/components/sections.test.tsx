import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BENEFITS, COMPANIES, FAQS, HERO, NAV_LINKS, PRIVACY, STEPS } from "@/lib/content";
import { Benefits } from "./benefits";
import { FaqList } from "./faq-list";
import { ForCompanies, telHref } from "./for-companies";
import { Hero } from "./hero";
import { HowItWorks } from "./how-it-works";
import { SiteFooter } from "./site-footer";
import { SiteHeader } from "./site-header";

describe("landing sections", () => {
  it("HowItWorks lists every step in order", () => {
    render(<HowItWorks />);
    const items = screen.getAllByRole("listitem");
    expect(items).toHaveLength(STEPS.length);
    STEPS.forEach((step, i) => expect(items[i]).toHaveTextContent(step.title));
  });

  it("HowItWorks sets each step as a heading with no index number or icon in front of it", () => {
    const { container } = render(<HowItWorks />);
    STEPS.forEach((step) => expect(screen.getByRole("heading", { level: 3, name: step.title })).toBeInTheDocument());
    expect(container.querySelector(".steps svg")).toBeNull();
    STEPS.forEach((_, i) => expect(screen.queryByText(String(i + 1))).toBeNull());
  });

  it("Hero sets the whole title in one ink (no two-tone accent) and marks the phone as an app fragment", () => {
    const { container } = render(<Hero links={{ appStore: null, playStore: null, companyPanel: "", contactEmail: null, contactPhone: null }} />);
    const title = screen.getByRole("heading", { level: 1 });
    expect(title).toHaveTextContent(HERO.title);
    expect(title.querySelector("span")).toBeNull();
    expect(container.querySelector(".hero-stage")).toHaveAttribute("data-ui");
  });

  it("every section part that animates is marked for the motion layer", () => {
    const { container } = render(<FaqList />);
    expect(container.querySelectorAll("details[data-reveal]")).toHaveLength(FAQS.length);
  });

  it("Benefits shows every benefit and the privacy promises under #privacy", () => {
    const { container } = render(<Benefits />);
    BENEFITS.forEach((b) =>
      expect(screen.getByRole("heading", { name: b.title })).toBeInTheDocument(),
    );
    const privacy = container.querySelector("#privacy")!;
    expect(within(privacy as HTMLElement).getByRole("heading", { name: PRIVACY.title })).toBeInTheDocument();
    PRIVACY.points.forEach((p) => expect(privacy).toHaveTextContent(p));
  });

  it("no section heading carries a small label above it (no eyebrows)", () => {
    const { container } = render(<Benefits />);
    expect(container.querySelector(".eyebrow")).toBeNull();
  });

  it("FaqList has one collapsible entry per question, closed at first", () => {
    const { container } = render(<FaqList />);
    const entries = container.querySelectorAll("details");
    expect(entries).toHaveLength(FAQS.length);
    entries.forEach((d) => expect(d.open).toBe(false));
    FAQS.forEach((f) => expect(screen.getByText(f.question)).toBeInTheDocument());
  });

  it("ForCompanies without a configured contact offers only the login (never a made-up address)", () => {
    render(<ForCompanies companyPanelUrl="https://company.uziy.mn" />);
    expect(screen.getByRole("link", { name: new RegExp(COMPANIES.cta) })).toHaveAttribute(
      "href",
      "https://company.uziy.mn",
    );
    expect(screen.queryByText(COMPANIES.contactTitle)).toBeNull();
    expect(document.querySelector('a[href^="mailto:"], a[href^="tel:"]')).toBeNull();
  });

  it("ForCompanies leads with email and phone when configured; the login becomes secondary", () => {
    render(
      <ForCompanies
        companyPanelUrl="https://company.uziy.mn"
        contactEmail="hello@example.mn"
        contactPhone="+976 7711-2233"
      />,
    );
    expect(screen.getByText(COMPANIES.contactTitle)).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /hello@example\.mn/ })).toHaveAttribute(
      "href",
      "mailto:hello@example.mn",
    );
    expect(screen.getByRole("link", { name: /7711-2233/ })).toHaveAttribute("href", "tel:+97677112233");
    expect(screen.getByRole("link", { name: new RegExp(COMPANIES.login) })).toHaveAttribute(
      "href",
      "https://company.uziy.mn",
    );
    expect(screen.queryByRole("link", { name: new RegExp(COMPANIES.cta) })).toBeNull();
  });

  it("telHref keeps only digits and a leading plus", () => {
    expect(telHref("+976 7711-2233")).toBe("tel:+97677112233");
    expect(telHref("(7711) 2233")).toBe("tel:77112233");
  });

  it("SiteHeader anchors every nav link to a section id on the page", () => {
    render(<SiteHeader companyPanelUrl="https://company.uziy.mn" />);
    const nav = within(screen.getByRole("navigation", { name: "Үндсэн цэс" }));
    NAV_LINKS.forEach((l) =>
      expect(nav.getByRole("link", { name: l.label })).toHaveAttribute(
        "href",
        l.href,
      ),
    );
    // The header button opens the company login; the nav link only scrolls to #companies.
    expect(screen.getByRole("link", { name: /Компанийн самбар/ })).toHaveAttribute(
      "href",
      "https://company.uziy.mn",
    );
  });

  it("SiteFooter shows the given year", () => {
    render(<SiteFooter year={2026} />);
    expect(screen.getByText(/© 2026 Uziy/)).toBeInTheDocument();
  });
});
