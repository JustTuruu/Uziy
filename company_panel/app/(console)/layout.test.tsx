import { render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth, type Me } from "@/lib/api";
import CompanyLayout from "./layout";

vi.mock("next/navigation", () => ({ usePathname: () => "/" }));

const company = (companyName: string | null): Me => ({
  id: 1,
  phoneNumber: "88112233",
  role: "COMPANY",
  gender: null,
  age: null,
  city: null,
  balance: 0,
  isVerified: true,
  companyName,
});

describe("Company console layout", () => {
  beforeEach(() => window.localStorage.clear());
  afterEach(() => window.localStorage.clear());

  it("shows the company name instead of the generic subtitle", async () => {
    auth.setUser(company("Khan Bank"));
    render(<CompanyLayout>x</CompanyLayout>);
    expect((await screen.findAllByText("Khan Bank")).length).toBe(2);
    expect(screen.queryByText("Компанийн самбар")).toBeNull();
    expect(screen.getByText("+976 8811 2233")).toBeTruthy();
  });

  it("falls back to a generic label when there is no session", () => {
    render(<CompanyLayout>x</CompanyLayout>);
    expect(screen.getAllByText("Компани").length).toBe(2);
  });
});
