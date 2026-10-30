# syntax=docker/dockerfile:1
# The console (company + admin areas, one Vite app) as static files behind nginx. Built from the repo root by
# docker-compose.yml.

FROM node:22-alpine AS build
# Baked into the bundle at build time: the address the BROWSER uses to reach the backend (the host's published
# port, not the compose service name). It is also the only API origin the CSP lets the page talk to.
ARG VITE_API_BASE_URL=http://localhost:8080
WORKDIR /repo
RUN corepack enable && corepack prepare pnpm@10.17.1 --activate

# Workspace manifests first: the install layer is reused until a dependency changes.
COPY pnpm-lock.yaml pnpm-workspace.yaml ./
COPY console/package.json console/
COPY landing/package.json landing/
COPY packages/ui/package.json packages/ui/
COPY packages/api-types/package.json packages/api-types/
RUN --mount=type=cache,id=uziy-pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --filter "console..."

COPY packages packages
COPY console console
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
# Writes console/dist and console/build/nginx/security-headers.conf.
RUN pnpm --filter console build

FROM nginx:1.27-alpine
COPY docker/console-nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /repo/console/build/nginx/security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY --from=build /repo/console/dist /usr/share/nginx/html
EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --retries=6 CMD wget -q -O /dev/null http://127.0.0.1:3000/ || exit 1
