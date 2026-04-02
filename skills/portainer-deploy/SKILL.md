---
name: portainer-deploy
description: >-
  Deploy to production via Portainer stacks and Docker Compose. Creates image-based compose
  files, Dockerfiles, build-and-push scripts, env templates, healthchecks, and webhook automation.
  Triggers: Portainer, production compose, container registry push, "deploy this", "ship it"
  (when project has Portainer config or container-based workflow). NOT for: serverless/PaaS,
  Kubernetes, IaC tools, package publishing, or standalone dev-only Dockerfiles.
---

# Easy Deploy

Get code running in production containers with minimal friction. This skill handles the full path from source code to running Portainer stack — Dockerfiles, compose files, image builds, environment config, and automation.

**Library lookups**: `search_packages` → `get_docs` for Docker, compose, and registry APIs before writing configs. 2-4 keyword queries.
**Mulching**: If `.mulch/` exists: `mulch prime` at start. `mulch record --tags <situation>` new patterns at end. Foxhound `search("deploy", project_root=root)` already includes mulch for discovery.

## Mental model

There are two worlds and a bridge between them:

**Development** — you build from source, mount local files, use env files, iterate fast. The compose file says `build: ./api` because you want hot-reload and quick feedback.

**Production** — pre-built images from a registry, no filesystem access, environment injected by the orchestrator. The compose file says `image: registry.example.com/api:v1.2.3` because the server has no access to your source code.

**The bridge** — a build script that turns source into registry images, and a production compose file that references those images. The skill's job is keeping the bridge intact as the project evolves.

## Discovering what exists

Before touching anything, understand the project's current deployment setup:

1. Find compose files — look in `deploy/`, `docker/`, project root. Which ones use `build:` (dev) vs `image:` (prod)?
2. Find Dockerfiles — one per deployable service, usually in service subdirectories
3. Find the build/push mechanism — shell script, CI pipeline, Makefile, GitHub Actions
4. Find env config — `.env.sample`, `.env.example`, `service_config.env.sample`
5. Find the container registry — ghcr.io, Docker Hub, ECR, self-hosted
6. Check for automation — Portainer webhooks, GitOps polling, CI/CD triggers

## Portainer: what it can and can't do

Portainer is a web UI for managing Docker containers. Stacks are its way of deploying multi-container apps from compose files. Understanding its constraints prevents frustrating deploy failures.

### Deployment methods (choose based on workflow)

| Method | Best for | Trade-off |
|--------|----------|-----------|
| **Web editor** | Small teams, quick feedback | Manual paste, no version history |
| **Git repository** | Teams wanting traceability | Every change is a commit, supports auto-update |
| **Upload** | Air-gapped or offline environments | Manual file transfer |
| **Custom template** | Repeated deployments across environments | Requires template setup upfront |

**Git-backed stacks** are the strongest option for production — every change is traceable, rollback is a git revert, and Portainer can auto-poll or accept webhooks to redeploy on push.

### Hard constraints

These will cause deploy failures if violated:

- **No `build:` directives** — Portainer (v2.29.2+) cannot execute build steps for remote environments. It fails with `Unable to upgrade to tcp, received 200`. Always use pre-built `image:` references.
- **No `env_file:` pointing to host paths** — the Portainer server doesn't have your local `.env` file. Use `${VAR}` substitution instead — Portainer's UI has an "Environment variables" section where you set these values, and it performs the substitution before deploying.
- **No source-code volume mounts** — `../app/src:/app/src:ro` doesn't exist on the server. Everything the container needs must be baked into the image. Named volumes for persistent data (`pg-data:/var/lib/postgresql/data`) are fine.
- **Bundled Compose version lags** — Portainer bundles an older Docker Compose binary. Avoid bleeding-edge features like `start_interval` in healthchecks (Docker Engine v25+). Stick to well-established compose syntax. If unsure, test with `docker compose config`.

### Environment variable flow

This is where most confusion lives. Here's how it actually works:

```
You define in compose:     environment: { DB_URL: ${DB_URL} }
                                            ↓
Portainer UI:              Environment Variables → DB_URL = postgres://...
                                            ↓
Portainer substitutes:     environment: { DB_URL: postgres://... }
                                            ↓
Container receives:        DB_URL=postgres://...
```

The compose file is a template. Portainer fills in the blanks from its environment variables UI. This means the compose file can be public (committed to git) while secrets stay in Portainer.

Use `${VAR:-default}` for optional variables with sensible defaults. Use `${VAR}` (no default) for required secrets — Portainer will substitute an empty string if unset, which surfaces the misconfiguration quickly.

## Structuring the compose files

### The two-file pattern

Most projects benefit from two compose files:

**`docker-compose.yml`** (development)
- Uses `build:` for local development
- Uses `env_file:` for convenience
- May mount source code for hot-reload
- May include dev-only services (Caddy for local HTTPS, debug tools)

**`docker-compose.portainer.yml`** (production)
- Uses `image:` from the registry
- Inlines environment with `${VAR}` substitution
- No source mounts
- Has a header comment documenting all required env vars and how to generate secrets
- Production-only services (backup, monitoring)

### Use YAML anchors to reduce duplication

When multiple services share config (same image, same env vars, same dependencies), use anchors:

```yaml
x-app-env: &app-env
  DATABASE_URL: ${DATABASE_URL}
  REDIS_URL: ${REDIS_URL}
  SECRET_KEY: ${SECRET_KEY}

x-app-base: &app-base
  image: ghcr.io/org/project/api:${IMAGE_TAG:-latest}
  environment:
    <<: *app-env
  depends_on:
    postgres:
      condition: service_healthy

services:
  api:
    <<: *app-base
    command: gunicorn app:wsgi
  worker:
    <<: *app-base
    command: celery -A app worker
```

This way, adding an env var to `x-app-env` automatically propagates to every service that uses it.

### Every service needs a healthcheck

Healthchecks aren't optional decoration — they're what makes `depends_on: condition: service_healthy` work, and they're what Portainer uses to show accurate container status. Without them, Portainer shows "running" even if the app inside is crash-looping.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/healthcheck/"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 20s   # grace period for slow startups
```

For minimal images without curl: `["CMD", "wget", "-qO-", "http://localhost:8000/health"]`
For databases: `["CMD", "pg_isready", "-U", "myuser"]`
For Redis: `["CMD", "redis-cli", "ping"]`

### Document the production file

The production compose file is often the only thing a deployer sees. Put a header comment that serves as a deploy guide:

```yaml
# project-name — Portainer stack
#
# Deploy: Stacks → Add stack → paste this → set env vars → deploy
# Update: Stacks → your stack → Pull and redeploy
#
# Required environment variables:
#   SECRET_KEY    — python -c "import secrets; print(secrets.token_hex(50))"
#   DB_PASSWORD   — openssl rand -base64 32
#   ...
#
# Profiles:
#   (none)    — core services
#   backup    — daily database backups
#   monitoring — prometheus + grafana
```

## Building and pushing images

### Build script pattern

A simple build script that handles the common workflow:

```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY="ghcr.io/yourorg/yourproject"
TAG="${1:-$(git rev-parse --short HEAD)}"

images=(
  "api:./api"
  "ui:./ui"
  "worker:./worker"
)

for entry in "${images[@]}"; do
  name="${entry%%:*}"
  context="${entry#*:}"
  docker build -t "${REGISTRY}/${name}:${TAG}" "${context}"
  docker push "${REGISTRY}/${name}:${TAG}"
  # Keep latest in sync
  if [[ "${TAG}" != "latest" ]]; then
    docker tag "${REGISTRY}/${name}:${TAG}" "${REGISTRY}/${name}:latest"
    docker push "${REGISTRY}/${name}:latest"
  fi
done
```

### Image tagging strategy

- **Git SHA tags** (`abc1234`) — every build is traceable to a commit. Use for automated builds.
- **Semver tags** (`v1.2.3`) — for releases. Makes rollback clear: redeploy `v1.2.2`.
- **`latest`** — convenient for "just give me the newest." But in production, pinning to a specific tag is safer because `latest` doesn't tell you what's actually running and makes rollback ambiguous.
- **`${IMAGE_TAG:-latest}`** in compose — lets deployers pin a version by setting one env var, while defaulting to latest for simplicity.

### CI/CD integration

The build script can be triggered by:
- **Git post-commit hook** — build on every commit (good for small teams)
- **CI pipeline** (GitLab CI, GitHub Actions) — build on merge to main
- **Manual** — run the script when you're ready to ship

For Portainer auto-update, combine with a git-backed stack:
1. CI builds and pushes images on merge
2. CI commits the updated image tag to the compose file in the repo
3. Portainer polls the repo (or receives a webhook) and redeploys

## Adding a new service

End-to-end checklist:

1. **Dockerfile** — create in the service directory. Follow project conventions (base image, non-root user, multi-stage if frontend/compiled). If no convention exists, use alpine bases and non-root users. `[eval: shape]` Dockerfile follows multi-stage pattern where applicable, no secrets baked into layers.
2. **Dev compose** — add with `build:` for local development. Add healthcheck and `depends_on` with conditions.
3. **Production compose** — add with `image:` from registry. Inline env vars using `${VAR}` or shared anchors. Add healthcheck. Add to appropriate network.
4. **Build script** — add to the images list.
5. **Env config** — add new variables to env sample AND production compose header comment.
6. **Validate** — `docker compose -f <production-compose> config`. `[eval: idempotence]` `docker compose up` is idempotent — re-running doesn't create duplicate volumes or networks.

## Validation

After any deployment change, check:

```bash
# YAML is valid and all references resolve
docker compose -f deploy/docker-compose.portainer.yml config > /dev/null

# No forbidden patterns in production file
grep -n 'build:' deploy/docker-compose.portainer.yml && echo "FAIL: build directive found"
grep -n 'env_file:' deploy/docker-compose.portainer.yml && echo "FAIL: env_file found"
grep -n '\.\./\|\./' deploy/docker-compose.portainer.yml | grep -v '#' | grep 'volumes:' -A5 && echo "WARN: check for source mounts"
```

## Setting up from scratch

If the project has no deployment setup:

1. Identify what runs — app server, workers, databases, caches, reverse proxy
2. Write a Dockerfile per custom service
3. Create `docker-compose.yml` for dev (with `build:`)
4. Create `.env.sample` documenting every variable
5. Create `docker-compose.portainer.yml` for production (with `image:`, inline `${VAR}`, header guide)
6. Create a build-push script
7. Validate both compose files
8. Consider git-backed stack + Portainer auto-update for continuous deployment
