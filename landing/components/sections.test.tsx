import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { BENEFITS, FAQS, NAV_LINKS, STEPS } from "@/lib/content";
import { Benefits } from "./benefits";
import { FaqList } from "./faq-list";
import { ForCompanies } from "./for-companies";
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

  it("Benefits shows every benefit", () => {
    render(<Benefits />);
    BENEFITS.forEach((b) =>
      expect(screen.getByRole("heading", { name: b.title })).toBeInTheDocument(),
    );
  });

  it("FaqList has one collapsible entry per question, closed at first", () => {
    const { container } = render(<FaqList />);
    const entries = container.querySelectorAll("details");
    expect(entries).toHaveLength(FAQS.length);
    entries.forEach((d) => expect(d.open).toBe(false));
    FAQS.forEach((f) => expect(screen.getByText(f.question)).toBeInTheDocument());
  });

  it("ForCompanies sends advertisers to the company panel", () => {
    render(<ForCompanies companyPanelUrl="https://company.uziy.mn" />);
    expect(
      screen.getByRole("link", { name: /Кампанит ажил эхлүүлэх/ }),
    ).toHaveAttribute("href", "https://company.uziy.mn");
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
