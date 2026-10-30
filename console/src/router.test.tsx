import { render, screen, waitFor } from "@testing-library/react";
import { createMemoryHistory, RouterProvider } from "@tanstack/react-router";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { auth } from "@shared/api/http";
import { aMe } from "@shared/test/fixtures";
import { createAppRouter } from "./router";

function openAt(path: string) {
  const router = createAppRouter(createMemoryHistory({ initialEntries: [path] }));
  render(<RouterProvider router={router} />);
  return router;
}

describe("the console's areas", () => {
  beforeEach(() => {
    window.localStorage.clear();
    // The pages load data on mount; these tests are only about where the router lands.
    vi.spyOn(globalThis, "fetch").mockImplementation(() => new Promise(() => {}));
  });
  afterEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  function signIn(role: "COMPANY" | "ADMIN") {
    auth.setToken("jwt");
    auth.setUser(aMe({ role }));
  }

  it("sends a visitor without a session to the sign-in page", async () => {
    const router = openAt("/campaigns");
    await waitFor(() => expect(router.state.location.pathname).toBe("/login"));
    expect(await screen.findByRole("button", { name: "Нэвтрэх" })).toBeInTheDocument();
  });

  it("keeps a company out of the admin area", async () => {
    signIn("COMPANY");
    const router = openAt("/admin/payouts");
    await waitFor(() => expect(router.state.location.pathname).toBe("/"));
  });

  it("sends an admin who opens the company area to /admin", async () => {
    signIn("ADMIN");
    const router = openAt("/campaigns");
    await waitFor(() => expect(router.state.location.pathname).toBe("/admin"));
  });

  it("opens an admin page for an admin, inside the admin layout", async () => {
    signIn("ADMIN");
    const router = openAt("/admin/payouts");
    await waitFor(() => expect(router.state.location.pathname).toBe("/admin/payouts"));
    expect(await screen.findByText("Супер Админ")).toBeInTheDocument();
  });

  it("says so for an unknown address", async () => {
    signIn("COMPANY");
    openAt("/no-such-page");
    expect(await screen.findByText("Хуудас олдсонгүй.")).toBeInTheDocument();
  });
});
