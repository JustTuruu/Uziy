import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { TableScroll } from "./table-scroll";

describe("<TableScroll>", () => {
  it("scrolls sideways itself, so a wide table never widens the page", () => {
    render(
      <TableScroll>
        <table>
          <tbody>
            <tr>
              <td>Утас</td>
            </tr>
          </tbody>
        </table>
      </TableScroll>,
    );
    const region = screen.getByRole("region", { name: "Хүснэгт" });
    expect(region.className).toContain("overflow-x-auto");
    expect(region).toContainElement(screen.getByRole("table"));
  });

  it("can be reached with the keyboard and named for its content", () => {
    render(<TableScroll aria-label="Хэрэглэгчид">x</TableScroll>);
    const region = screen.getByRole("region", { name: "Хэрэглэгчид" });
    expect(region).toHaveAttribute("tabindex", "0");
  });
});
