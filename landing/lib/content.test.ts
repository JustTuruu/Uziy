import { describe, expect, it } from "vitest";
import * as content from "./content";
import { BENEFITS, FAQS, HERO, NAV_LINKS, PRIVACY, STEPS } from "./content";

describe("NAV_LINKS", () => {
  it("point at in-page anchors that the page defines", () => {
    const sectionIds = ["how", "benefits", "privacy", "faq", "companies"];
    expect(NAV_LINKS.map((l) => l.href)).toEqual(sectionIds.map((id) => `#${id}`));
  });
});

describe("positioning", () => {
  it("leads with brands and the viewer's opinion, not with earning money", () => {
    expect(HERO.title.toLowerCase()).not.toContain("мөнгө");
    expect(HERO.title).toContain("санал бодлоо");
    expect(HERO.title).toContain(HERO.accent);
  });

  // Every visible sentence lives in content.ts (2026-10-22), so this covers the whole page.
  it("never talks about money, rewards or payouts anywhere on the page", () => {
    const everything = JSON.stringify(content);
    expect(everything).not.toMatch(/₮|төгрөг|мөнгө|урамшуул|хэтэвч|талархал|төлнө|орлого/i);
  });
});

describe("facts stay true to the product", () => {
  it("the password-reset answer describes texting a code to 144773, not receiving one", () => {
    const reset = FAQS.find((f) => f.question.includes("Нууц үг"))!;
    expect(reset.answer).toContain("144773");
    expect(reset.answer).not.toMatch(/ирсэн .*код/);
  });

  it("tells viewers they can delete their account and what companies see", () => {
    expect(FAQS.some((f) => f.question.includes("устгаж"))).toBe(true);
    expect(FAQS.some((f) => f.question.includes("Компаниуд миний мэдээллийг"))).toBe(true);
    expect(PRIVACY.points.join(" ")).toContain("5-аас цөөн");
  });

  it("keeps the agreed numbers: 13+, 30 s – 2 min, 2–3 questions", () => {
    const text = JSON.stringify(content);
    expect(text).toContain("13 ба түүнээс дээш");
    expect(text).toContain("30 секундээс 2 минутын");
    expect(text).toContain("2–3");
  });

  it("has a step per icon slot and a title for every benefit", () => {
    expect(STEPS).toHaveLength(4);
    BENEFITS.forEach((b) => expect(b.title.trim()).not.toBe(""));
  });
});
