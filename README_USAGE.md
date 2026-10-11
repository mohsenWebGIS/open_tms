# Open TMS — Usage Guide

## Default Credentials

After running the comprehensive seed (`cd backend && npx tsx src/scripts/comprehensive-seed.ts`):

| Role | Email | Password |
|---|---|---|
| **TMS Admin** | `admin@meridian-tms.demo` | `Password1!` |
| **TMS Dispatcher** | `dispatch@meridian-tms.demo` | `Password1!` |
| **TMS Ops Manager** | `ops-manager@meridian-tms.demo` | `Password1!` |
| **TMS Warehouse** | `warehouse@meridian-tms.demo` | `Password1!` |
| **TMS Finance** | `finance@meridian-tms.demo` | `Password1!` |
| **Customer Portal** | `admin@nordic.demo` | `Portal123!` |
| **Customer Portal** | `viewer@axiom.demo` | `Portal123!` |
| **Carrier Portal** | `dispatch@continental.demo` | `Carrier123!` |
| **Carrier Portal** | `dispatch@polarchain.demo` | `Carrier123!` |

## URL Map

| Service | URL |
|---|---|
| Frontend (admin app) | http://localhost:5173 |
| Backend API | http://localhost:3001 |
| API Docs (Swagger) | http://localhost:3001/docs |
| Auth Service | http://localhost:3002 |
| Database | `postgresql://tms:tms@localhost:55432/tms` |

## Quick Commands

| Action | Command |
|---|---|
| Start everything | `npm run dev` |
| Stop dev servers | `pkill -f "tsx watch" && pkill -f "vite"` |
| Start DB only | `docker compose up -d db` |
| Stop database container | `docker compose stop db` |
| Apply migrations | `cd backend && npx prisma migrate deploy` |
| Generate Prisma client | `cd backend && npm run prisma:generate` |
| Full seed (wipes data) | `cd backend && npx tsx src/scripts/comprehensive-seed.ts` |
| Seed (keep existing data) | `cd backend && npx tsx src/scripts/comprehensive-seed.ts --no-wipe` |
| Run tests | `npm run test` |
| Lint | `npm run lint` |
| Create admin manually | `cd backend && npx tsx src/scripts/create-admin.ts --email user@example.com --password "Secret1!"` |

## Important Tips

### First-time Setup Order
1. `docker compose up -d db` — start PostgreSQL
2. `cd backend && npx prisma migrate deploy && npm run prisma:generate` — schema
3. `npm -w packages/shared run build` — shared types
4. `npm run dev` — start servers
5. Seed with `cd backend && npx tsx src/scripts/comprehensive-seed.ts` — demo data

### API Envelope
All endpoints return `{ data, error }`. Success: `{ data: {...}, error: null }`. Error: `{ data: null, error: "message" }`.

### Auth
- Login at `POST /api/v1/auth/login` with `{ email, password }`
- JWT token returned in response. Include in `Authorization: Bearer <token>` header.
- Auth service runs separately on port 3002.

### Environment Variables
Copy `production.env.template` for production. For dev, `.env` files are auto-created in `backend/` and `frontend/`.

### Workers
Background workers (email, webhooks, projections, audit) run embedded in dev. For production, run as separate containers via `docker compose up --scale worker=3 -d`.

### Troubleshooting
- **DB not connecting**: Ensure Docker is running and `docker compose up -d db` is active
- **Migration failures**: `cd backend && npx prisma migrate resolve --applied <migration_name>` to mark failed migrations as applied
- **Port conflicts**: Backend uses 3001, frontend 5173, DB 55432. Check for conflicts with `lsof -i :<port>`
- **Tests failing**: Run `npm -w packages/shared run build` first (shared types needed)