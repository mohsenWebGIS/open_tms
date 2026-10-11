# Open TMS — AGENTS.md

## Project Overview

Open-source Transport Management System (TMS). TypeScript monorepo with CQRS/event-driven backend (Fastify + Prisma + PostgreSQL), React frontend (Vite), and supporting services.

## Quick Start

```bash
# First time setup
npm install
docker compose up -d db
cd backend && npx prisma migrate deploy && npm run prisma:generate && cd ..
npm -w packages/shared run build

# Start dev servers
npm run dev

# Seed demo data
cd backend && npx tsx src/scripts/comprehensive-seed.ts
```

## URL Map

| Service | URL |
|---|---|
| Frontend | http://localhost:5173 |
| Backend API | http://localhost:3001 |
| API Docs (Swagger) | http://localhost:3001/docs |
| Database | postgresql://tms:tms@localhost:55432/tms |

## Default Credentials

See `README_USAGE.md`.

## Project Structure

```
opentms/
├── backend/          # Fastify API server (port 3001)
│   ├── src/
│   │   ├── commands/     # CQRS command handlers
│   │   ├── events/       # Domain events + projections
│   │   ├── repositories/ # Data access layer
│   │   ├── routes/       # Thin HTTP route handlers
│   │   ├── services/     # Business logic orchestration
│   │   ├── auth/         # Auth, RBAC, org-scope middleware
│   │   ├── queue/        # pg-boss queue adapter
│   │   ├── di/           # Dependency injection container
│   │   └── scripts/      # Seed, backfill, utility scripts
│   └── prisma/           # Schema + migrations
├── frontend/         # React + Vite SPA (port 5173)
├── auth-service/     # Standalone auth microservice (port 3002)
├── edi-collector/    # EDI file collection service
├── webhook-service/  # Webhook delivery service
├── packages/shared/  # Shared TypeScript types
└── www/              # Marketing website
```

## Key Architecture Rules

- **CQRS**: All writes go through `commandBus.dispatch()` inside a transaction. Events publish after commit. Reads go through repositories or denormalized read models.
- **Thin routes**: Routes only parse input, dispatch commands/call repos, shape response. No business logic.
- **No raw Prisma in routes**: All DB access through repository classes.
- **No raw SQL** outside repositories (and almost never there either).
- **Multi-tenancy**: Every entity carries `orgId`. Route plugins register `registerOrgScope(server)` for `req.orgId!`.
- **API envelope**: All endpoints return `{ data, error }`.
- **Events + projections**: State changes emit domain events. Projections build denormalized read models for fast list queries.
- **pg-boss queues**: Background work (email, webhooks, audit, projections) runs through pg-boss queues.
- **Tests**: Every command handler needs tests for success, event emission, and error cases.

## Commands

| Command | Description |
|---|---|
| `npm run dev` | Start backend + frontend concurrently |
| `npm run build` | Build shared, backend, frontend |
| `npm run test` | Run all tests |
| `npm run lint` | Lint all files |
| `npm run format` | Prettier format |
| `pkill -f "tsx watch" && pkill -f "vite"` | Stop dev servers |
| `docker compose stop db` | Stop database container |
| `cd backend && npx tsx src/scripts/comprehensive-seed.ts` | Full seed (wipes first) |
| `cd backend && npx tsx src/scripts/comprehensive-seed.ts --no-wipe` | Seed preserving existing data |
| `cd backend && npx prisma migrate deploy` | Apply pending migrations |
| `cd backend && npm run prisma:generate` | Generate Prisma client |

## Enforcing Rules

This project uses `.claude/rules/` for AI agent conventions. Refer to individual rules by name:
- `architecture.md` — layering, thin routes, repository pattern
- `cqrs-and-events.md` — commands, events, projections, new-entity checklist
- `multi-tenancy.md` — orgId scoping per surface
- `security.md` — auth guards, rate limiting, PII, webhooks
- `backend.md` — API envelope, DI, repositories, read models
- `database.md` — indexing, migrations, soft deletes
- `frontend.md` — React conventions, theme system
- `design-system.md` — shadcn/ui, styling rules
- `api-design.md` — REST, envelope, pagination, validation
- `transactions-and-concurrency.md` — no I/O in transactions, locking
- `queues-and-jobs.md` — pg-boss workers, backoff, dead letters
- `pre-commit-checklist.md` — walk before every PR

## Key Dependencies

- **Backend**: Fastify 4, Prisma 5, pg-boss, Zod, Handlebars (email templates), node-x12 (EDI), nodemailer
- **Frontend**: React 18, Vite 5, React Router 6, Tailwind CSS 3, shadcn/ui (Radix primitives), Leaflet (maps), dnd-kit (drag-drop), Lucide icons
- **Infra**: PostgreSQL 16, Docker, pg-boss for queue