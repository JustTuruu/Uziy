# syntax=docker/dockerfile:1
# One image recipe for both Next.js panels (they share the pnpm workspace and
# packages/ui). Pick the app with the APP build arg: admin_panel | company_panel.
# Built from the repo root by docker-compose.yml.

FROM node:22-alpine
ARG APP
# Baked into the client bundle at build time: the address the BROWSER uses to
# reach the backend (the host's published port, not the compose service name).
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
# Where each panel sends the other (admins sign in on the company login page and are handed to the admin panel).
ARG NEXT_PUBLIC_COMPANY_PANEL_URL=http://localhost:3000
ARG NEXT_PUBLIC_ADMIN_PANEL_URL=http://localhost:3001
ENV NEXT_TELEMETRY_DISABLED=1
WORKDIR /repo
RUN corepack enable && corepack prepare pnpm@10.17.1 --activate

# Workspace manifests first: the install layer is reused until a dependency changes.
COPY pnpm-lock.yaml pnpm-workspace.yaml ./
COPY admin_panel/package.json admin_panel/
COPY company_panel/package.json company_panel/
COPY landing/package.json landing/
COPY packages/ui/package.json packages/ui/
RUN --mount=type=cache,id=uziy-pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile --filter "${APP}..."

COPY packages/ui packages/ui
COPY ${APP} ${APP}
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL} \
    NEXT_PUBLIC_COMPANY_PANEL_URL=${NEXT_PUBLIC_COMPANY_PANEL_URL} \
    NEXT_PUBLIC_ADMIN_PANEL_URL=${NEXT_PUBLIC_ADMIN_PANEL_URL}
RUN pnpm --filter "${APP}" build

ENV NODE_ENV=production \
    APP=${APP}
EXPOSE 3000
CMD ["sh", "-c", "cd \"$APP\" && exec ./node_modules/.bin/next start -H 0.0.0.0 -p \"${PORT:-3000}\""]
