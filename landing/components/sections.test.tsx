import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BENEFITS, COMPANIES, FAQS, NAV_LINKS, PRIVACY, STEPS } from "@/lib/content";
import { Benefits } from "./benefits";
import { FaqList } from "./faq-list";
import { ForCompanies } from "./for-companies";
import { splitAccent } from "./hero";
import { HowItWorks, STEP_ICONS } from "./how-it-works";
import { SiteFooter } from "./site-footer";
import { SiteHeader } from "./site-header";

describe("landing sections", () => {
  it("HowItWorks lists every step in order", () => {
    render(<HowItWorks />);
    const items = screen.getAllByRole("listitem");
    expect(items).toHaveLength(STEPS.length);
    STEPS.forEach((step, i) => expect(items[i]).toHaveTextContent(step.title));
  });

  it("HowItWorks has an icon for every step", () => {
    expect(STEP_ICONS).toHaveLength(STEPS.length);
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

  it("ForCompanies opens the company login and says Uziy creates accounts", () => {
    render(<ForCompanies companyPanelUrl="https://company.uziy.mn" />);
    expect(screen.getByRole("link", { name: new RegExp(COMPANIES.cta) })).toHaveAttribute(
      "href",
      "https://company.uziy.mn",
    );
    expect(screen.getByText(COMPANIES.accountNote)).toBeInTheDocument();
    // No configured address → no contact link (never a made-up email).
    expect(screen.queryByRole("link", { name: new RegExp(COMPANIES.contact) })).toBeNull();
  });

  it("ForCompanies shows the contact link only when an address is configured", () => {
    render(<ForCompanies companyPanelUrl="https://company.uziy.mn" contactEmail="hello@example.mn" />);
    expect(screen.getByRole("link", { name: new RegExp(COMPANIES.contact) })).toHaveAttribute(
      "href",
      "mailto:hello@example.mn",
    );
  });

  it("splitAccent keeps the whole title and isolates the accent", () => {
    expect(splitAccent("A b C", "b")).toEqual(["A ", "b", " C"]);
    expect(splitAccent("A b C", "x")).toEqual(["A b C", "", ""]);
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
    const hrefs = screen
      .getAllByRole("link", { name: "Компаниудад" })
      .map((a) => a.getAttribute("href"));
    expect(hrefs).toContain("https://company.uziy.mn");
  });

  it("SiteFooter shows the given year", () => {
    render(<SiteFooter year={2026} />);
    expect(screen.getByText(/© 2026 Uziy/)).toBeInTheDocument();
  });
});
