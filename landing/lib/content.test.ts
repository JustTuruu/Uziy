import { describe, expect, it } from "vitest";
import {
  BENEFITS,
  COMPANIES,
  FAQS,
  FOOTER,
  HERO,
  NAV_LINKS,
  STEPS,
} from "./content";

describe("NAV_LINKS", () => {
  it("point at in-page anchors that the page defines", () => {
    const sectionIds = ["how", "benefits", "faq", "companies"];
    expect(NAV_LINKS.map((l) => l.href)).toEqual(sectionIds.map((id) => `#${id}`));
  });
});

describe("positioning", () => {
  it("leads with brands and the viewer's opinion, not with earning money", () => {
    expect(HERO.title.toLowerCase()).not.toContain("мөнгө");
    expect(HERO.title).toContain("санал бодлоо");
  });

  it("never talks about money, rewards or payouts", () => {
    const everything = JSON.stringify({ HERO, STEPS, BENEFITS, FAQS, COMPANIES, FOOTER });
    expect(everything).not.toMatch(/₮|төгрөг|мөнгө|урамшуул|хэтэвч|талархал|төлнө/i);
  });
});
