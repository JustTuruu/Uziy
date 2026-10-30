import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
  RouterProvider,
} from "@tanstack/react-router";
import { describe, expect, it } from "vitest";
import { Link, useParams, usePathname, useRouter } from "./navigation";

function renderAt(path: string, page: () => React.ReactNode) {
  const root = createRootRoute({ component: Outlet });
  const routes = [
    createRoute({ getParentRoute: () => root, path: "/", component: page }),
    createRoute({ getParentRoute: () => root, path: "/campaigns/$id", component: page }),
    createRoute({ getParentRoute: () => root, path: "/login", component: () => <p>login-page</p> }),
  ];
  const router = createRouter({
    routeTree: root.addChildren(routes),
    history: createMemoryHistory({ initialEntries: [path] }),
  });
  render(<RouterProvider router={router} />);
  return router;
}

describe("navigation adapter", () => {
  it("reads the path and the route's parameters", async () => {
    function Page() {
      const { id } = useParams<{ id: string }>();
      return <p>{`${usePathname()} id=${id}`}</p>;
    }
    renderAt("/campaigns/7", Page);
    expect(await screen.findByText("/campaigns/7 id=7")).toBeInTheDocument();
  });

  it("replace() moves to another page", async () => {
    function Page() {
      const router = useRouter();
      return <button onClick={() => router.replace("/login")}>go</button>;
    }
    const router = renderAt("/", Page);
    await userEvent.click(await screen.findByRole("button", { name: "go" }));
    expect(await screen.findByText("login-page")).toBeInTheDocument();
    expect(router.state.location.pathname).toBe("/login");
  });

  it("a Link navigates inside the app", async () => {
    renderAt("/", () => <Link href="/login">Нэвтрэх</Link>);
    await userEvent.click(await screen.findByRole("link", { name: "Нэвтрэх" }));
    expect(await screen.findByText("login-page")).toBeInTheDocument();
  });

  it("a Link outside any router is a plain anchor", () => {
    render(<Link href="/campaigns/3">Судалгаа</Link>);
    expect(screen.getByRole("link", { name: "Судалгаа" })).toHaveAttribute("href", "/campaigns/3");
  });
});
