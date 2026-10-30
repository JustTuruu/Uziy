import { useMemo, type AnchorHTMLAttributes } from "react";
import {
  Link as RouterLink,
  useLocation,
  useNavigate,
  useParams as useRouteParams,
  useRouter as useTanStackRouter,
} from "@tanstack/react-router";
import type { NavLinkProps } from "@uziy/ui";

/**
 * Pattern: Adapter — the pages speak a small, router-neutral navigation API (`useRouter().push(href)`,
 * `<Link href>`, `usePathname()`, `useParams()`); this file maps it onto TanStack Router. Pages and their tests
 * then never import the router directly, and a component rendered without a router (a unit test) still draws a
 * plain link.
 */

export interface AppRouter {
  push(href: string): void;
  replace(href: string): void;
  back(): void;
}

export function useRouter(): AppRouter {
  const navigate = useNavigate();
  return useMemo(
    () => ({
      push: (href) => void navigate({ to: href }),
      replace: (href) => void navigate({ to: href, replace: true }),
      back: () => window.history.back(),
    }),
    [navigate],
  );
}

export function usePathname(): string {
  return useLocation({ select: (location) => location.pathname });
}

/** The current route's path parameters, e.g. `{ id: "7" }` on `/campaigns/7`. */
export function useParams<T extends Record<string, string>>(): T {
  return useRouteParams({ strict: false }) as T;
}

type LinkProps = Omit<AnchorHTMLAttributes<HTMLAnchorElement>, "href"> & { href: string };

/** An in-app link: client-side navigation inside the router, a plain anchor outside it. */
export function Link({ href, children, ...rest }: LinkProps) {
  const router = useTanStackRouter({ warn: false });
  if (!router) {
    return (
      <a href={href} {...rest}>
        {children}
      </a>
    );
  }
  return (
    <RouterLink to={href} {...rest}>
      {children}
    </RouterLink>
  );
}

/** The sidebar's link strategy (`@uziy/ui` Sidebar `linkComponent`). */
export function SidebarLink({ href, children, ...rest }: NavLinkProps) {
  return (
    <Link href={href} {...rest}>
      {children}
    </Link>
  );
}
