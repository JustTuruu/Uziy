import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import type { SelectOption } from "@uziy/ui";
import { ANY, NO_USER_FILTERS, type UserFilters } from "@/lib/user-filters";
import { UserFilterBar } from "./user-filter-bar";

const CITIES: SelectOption[] = [
  { value: ANY, label: "Бүх аймаг, хот" },
  { value: "Улаанбаатар", label: "Улаанбаатар" },
  { value: "Орхон", label: "Орхон" },
];

const companies = (count: number): SelectOption[] => [
  { value: ANY, label: "Бүх компани" },
  ...Array.from({ length: count }, (_, i) => ({ value: String(i + 1), label: `Компани ${i + 1}` })),
];

function Harness({
  initial = NO_USER_FILTERS,
  companyCount = 2,
  onChange,
}: {
  initial?: UserFilters;
  companyCount?: number;
  onChange?: (f: UserFilters) => void;
}) {
  const [filters, setFilters] = useState(initial);
  return (
    <UserFilterBar
      filters={filters}
      cities={CITIES}
      companies={companies(companyCount)}
      onChange={(f) => {
        setFilters(f);
        onChange?.(f);
      }}
    />
  );
}

describe("<UserFilterBar>", () => {
  it("searches by phone only", async () => {
    const onChange = vi.fn();
    render(<Harness onChange={onChange} />);
    const phone = screen.getByRole("searchbox", { name: "Утасны дугаар" });
    expect(phone).toHaveAttribute("placeholder", "Утасны дугаараар хайх...");
    await userEvent.type(phone, "88");
    expect(onChange).toHaveBeenLastCalledWith({ ...NO_USER_FILTERS, phone: "88" });
  });

  it("picks a city from the ready list", async () => {
    const onChange = vi.fn();
    render(<Harness onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox", { name: "Аймаг, хот" }));
    await userEvent.click(screen.getByRole("option", { name: "Орхон" }));
    expect(onChange).toHaveBeenLastCalledWith({ ...NO_USER_FILTERS, city: "Орхон" });
  });

  it("picks a company; a long list gets a type-ahead box", async () => {
    const onChange = vi.fn();
    render(<Harness companyCount={12} onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox", { name: "Компани" }));
    await userEvent.keyboard("Компани 12{Enter}");
    expect(onChange).toHaveBeenLastCalledWith({ ...NO_USER_FILTERS, companyId: "12" });
  });

  it("a short company list opens without a search box", async () => {
    render(<Harness companyCount={2} />);
    await userEvent.click(screen.getByRole("combobox", { name: "Компани" }));
    expect(screen.getAllByRole("option")).toHaveLength(3);
    expect(screen.queryByRole("searchbox", { name: "Компанийн нэрээр хайх..." })).toBeNull();
  });

  it("'Цэвэрлэх' is off with no filters and resets every filter", async () => {
    const onChange = vi.fn();
    const { unmount } = render(<Harness onChange={onChange} />);
    expect(screen.getByRole("button", { name: "Цэвэрлэх" })).toBeDisabled();
    unmount();

    render(
      <Harness
        initial={{ verification: "VERIFIED", phone: "88", city: "Орхон", companyId: "1" }}
        onChange={onChange}
      />,
    );
    await userEvent.click(screen.getByRole("button", { name: "Цэвэрлэх" }));
    expect(onChange).toHaveBeenLastCalledWith(NO_USER_FILTERS);
    expect(screen.getByRole("searchbox", { name: "Утасны дугаар" })).toHaveValue("");
    expect(screen.getByRole("combobox", { name: "Аймаг, хот" })).toHaveTextContent("Бүх аймаг, хот");
  });
});
