import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { COMING_SOON_LABEL, StoreButtons } from "./store-buttons";

describe("<StoreButtons>", () => {
  it("shows disabled 'Удахгүй' buttons until the app is published", () => {
    render(<StoreButtons links={{ appStore: null, playStore: null }} />);

    expect(screen.queryAllByRole("link")).toHaveLength(0);
    const buttons = screen.getAllByRole("button");
    expect(buttons).toHaveLength(2);
    buttons.forEach((b) => {
      expect(b).toBeDisabled();
      expect(b).toHaveTextContent(COMING_SOON_LABEL);
    });
  });

  it("links to each store once its URL is known", () => {
    render(
      <StoreButtons
        links={{
          appStore: "https://apps.apple.com/app/uziy",
          playStore: "https://play.google.com/store/apps/uziy",
        }}
      />,
    );

    expect(screen.getByRole("link", { name: /App Store/ })).toHaveAttribute(
      "href",
      "https://apps.apple.com/app/uziy",
    );
    expect(screen.getByRole("link", { name: /Google Play/ })).toHaveAttribute(
      "href",
      "https://play.google.com/store/apps/uziy",
    );
  });

  it("can have one store live and the other still coming", () => {
    render(
      <StoreButtons
        links={{ appStore: null, playStore: "https://play.google.com/x" }}
      />,
    );

    expect(screen.getAllByRole("link")).toHaveLength(1);
    expect(screen.getAllByRole("button")).toHaveLength(1);
  });
});
