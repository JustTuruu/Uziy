import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { useState } from "react";
import { describe, expect, it, vi } from "vitest";
import { matchOptions, Select, stepIndex, type SelectOption } from "./select";

const OPTIONS: SelectOption[] = [
  { value: "ALL", label: "Бүх судалгаа" },
  { value: "1", label: "Шинэ 5G багц" },
  { value: "2", label: "Гэр бүлийн багц" },
];

function Controlled({ onChange }: { onChange?: (v: string) => void }) {
  const [value, setValue] = useState("1");
  return (
    <Select
      label="Судалгаа"
      options={OPTIONS}
      value={value}
      onValueChange={(v) => {
        setValue(v);
        onChange?.(v);
      }}
    />
  );
}

describe("stepIndex", () => {
  it("moves by one and stays inside the list", () => {
    expect(stepIndex(1, 1, 3)).toBe(2);
    expect(stepIndex(2, 1, 3)).toBe(2);
    expect(stepIndex(0, -1, 3)).toBe(0);
    expect(stepIndex(2, -1, 3)).toBe(1);
  });
});

describe("<Select>", () => {
  it("shows the selected label, closed at first", () => {
    render(<Controlled />);
    const trigger = screen.getByRole("combobox", { name: "Судалгаа" });
    expect(trigger).toHaveTextContent("Шинэ 5G багц");
    expect(trigger).toHaveAttribute("aria-expanded", "false");
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });

  it("falls back to the placeholder when no option matches", () => {
    render(
      <Select options={OPTIONS} value="zzz" onValueChange={() => {}} aria-label="X" />,
    );
    expect(screen.getByRole("combobox", { name: "X" })).toHaveTextContent("Сонгох");
  });

  it("opens on click, marks the current option and picks another", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox"));

    const options = screen.getAllByRole("option");
    expect(options).toHaveLength(3);
    expect(options[1]).toHaveAttribute("aria-selected", "true");

    await userEvent.click(screen.getByRole("option", { name: "Гэр бүлийн багц" }));
    expect(onChange).toHaveBeenCalledWith("2");
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    expect(screen.getByRole("combobox")).toHaveTextContent("Гэр бүлийн багц");
  });

  it("works from the keyboard: open, move, choose", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    screen.getByRole("combobox").focus();

    await userEvent.keyboard("{ArrowDown}");
    expect(screen.getByRole("listbox")).toBeInTheDocument();
    await userEvent.keyboard("{ArrowDown}{Enter}");

    expect(onChange).toHaveBeenCalledWith("2");
  });

  it("Home and End jump to the ends", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    screen.getByRole("combobox").focus();
    await userEvent.keyboard("{Enter}{Home}{Enter}");
    expect(onChange).toHaveBeenLastCalledWith("ALL");

    await userEvent.keyboard("{Enter}{End}{Enter}");
    expect(onChange).toHaveBeenLastCalledWith("2");
  });

  it("Escape closes without changing the value", async () => {
    const onChange = vi.fn();
    render(<Controlled onChange={onChange} />);
    screen.getByRole("combobox").focus();
    await userEvent.keyboard("{Enter}{ArrowDown}{Escape}");

    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    expect(onChange).not.toHaveBeenCalled();
  });

  it("closes when pressing outside", async () => {
    render(
      <>
        <Controlled />
        <p>outside</p>
      </>,
    );
    await userEvent.click(screen.getByRole("combobox"));
    await userEvent.click(screen.getByText("outside"));
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
  });

  it("announces the highlighted option", async () => {
    render(<Controlled />);
    const trigger = screen.getByRole("combobox");
    trigger.focus();
    await userEvent.keyboard("{Enter}");
    const active = trigger.getAttribute("aria-activedescendant");
    expect(document.getElementById(active!)).toHaveTextContent("Шинэ 5G багц");
  });
});

const COMPANIES: SelectOption[] = [
  { value: "ALL", label: "Бүх компани" },
  { value: "10", label: "MobiCom" },
  { value: "11", label: "Голомт банк" },
  { value: "12", label: "Unitel" },
];

function Searchable({ onChange }: { onChange?: (v: string) => void }) {
  const [value, setValue] = useState("ALL");
  return (
    <Select
      label="Компани"
      searchable
      searchPlaceholder="Компани хайх..."
      options={COMPANIES}
      value={value}
      onValueChange={(v) => {
        setValue(v);
        onChange?.(v);
      }}
    />
  );
}

describe("matchOptions", () => {
  it("keeps every option for an empty or blank query", () => {
    expect(matchOptions(COMPANIES, "")).toBe(COMPANIES);
    expect(matchOptions(COMPANIES, "   ")).toBe(COMPANIES);
  });

  it("matches a label substring ignoring case, Cyrillic too", () => {
    expect(matchOptions(COMPANIES, "mob").map((o) => o.value)).toEqual(["10"]);
    expect(matchOptions(COMPANIES, "ГОЛОМТ").map((o) => o.value)).toEqual(["11"]);
    expect(matchOptions(COMPANIES, "zzz")).toEqual([]);
  });
});

describe("<Select searchable>", () => {
  it("has no search box unless asked", async () => {
    render(<Controlled />);
    await userEvent.click(screen.getByRole("combobox"));
    expect(screen.queryByRole("searchbox")).not.toBeInTheDocument();
  });

  it("opens with the search box focused and narrows the options as you type", async () => {
    render(<Searchable />);
    await userEvent.click(screen.getByRole("combobox", { name: "Компани" }));

    const search = screen.getByRole("searchbox", { name: "Компани хайх..." });
    expect(search).toHaveFocus();
    await userEvent.type(search, "голомт");

    expect(screen.getAllByRole("option").map((o) => o.textContent)).toEqual([
      "Голомт банк",
    ]);
  });

  it("chooses the highlighted match with Enter and returns focus to the trigger", async () => {
    const onChange = vi.fn();
    render(<Searchable onChange={onChange} />);
    const trigger = screen.getByRole("combobox", { name: "Компани" });
    trigger.focus();
    await userEvent.keyboard("{Enter}");
    await userEvent.keyboard("uni{Enter}");

    expect(onChange).toHaveBeenCalledWith("12");
    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
    expect(trigger).toHaveTextContent("Unitel");
  });

  it("moves through the matches with the arrows and announces the active one", async () => {
    const onChange = vi.fn();
    render(<Searchable onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox"));
    const search = screen.getByRole("searchbox");
    await userEvent.keyboard("{ArrowDown}");

    const active = search.getAttribute("aria-activedescendant");
    expect(document.getElementById(active!)).toHaveTextContent("MobiCom");
    await userEvent.keyboard("{Enter}");
    expect(onChange).toHaveBeenCalledWith("10");
  });

  it("lets Space type into the search box instead of choosing", async () => {
    const onChange = vi.fn();
    render(<Searchable onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox"));
    await userEvent.keyboard("Голомт ба");

    expect(screen.getByRole("searchbox")).toHaveValue("Голомт ба");
    expect(onChange).not.toHaveBeenCalled();
    expect(screen.getAllByRole("option")).toHaveLength(1);
  });

  it("says so when nothing matches, and Enter then changes nothing", async () => {
    const onChange = vi.fn();
    render(<Searchable onChange={onChange} />);
    await userEvent.click(screen.getByRole("combobox"));
    await userEvent.keyboard("zzz");

    expect(screen.queryAllByRole("option")).toHaveLength(0);
    expect(screen.getByRole("status")).toHaveTextContent("Олдсонгүй");
    await userEvent.keyboard("{Enter}");
    expect(onChange).not.toHaveBeenCalled();
  });

  it("Escape closes, clears the typed text and refocuses the trigger", async () => {
    render(<Searchable />);
    const trigger = screen.getByRole("combobox");
    await userEvent.click(trigger);
    await userEvent.keyboard("mob{Escape}");

    expect(screen.queryByRole("listbox")).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
    await userEvent.click(trigger);
    expect(screen.getByRole("searchbox")).toHaveValue("");
    expect(screen.getAllByRole("option")).toHaveLength(COMPANIES.length);
  });
});
