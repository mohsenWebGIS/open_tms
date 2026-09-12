#!/usr/bin/env bash
set -euo pipefail

# reproduce_session.sh
# Reproduce the actions performed during the current session to provision
# a local demo instance of Open TMS in this repository.
#
# What this script does (in order):
# 1. Start the local Postgres database via docker compose (service name: db)
# 2. Wait for Postgres to be ready
# 3. Ensure Node dependencies are installed (fresh install)
# 4. Resolve a paused Prisma migration (safe if already applied)
# 5. Apply remaining Prisma migrations
# 6. Generate Prisma client
# 7. Build the local shared package (packages/shared)
# 8. Run the comprehensive demo seed script (wipes by default)
#
# Run from the repository root:
#   bash scripts/reproduce_session.sh

DB_SERVICE="db"
DB_PORT=55432
DB_USER="tms"
DB_PASSWORD="tms"
DB_NAME="tms"
DB_CONTAINER_NAME="open_tms-db-1"
DATABASE_URL="postgresql://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME}"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
err() { echo "[ERROR] $*"; }

# Detect docker compose command
DOCKER_COMPOSE_CMD=""
if docker compose version &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null && docker-compose version &>/dev/null; then
  DOCKER_COMPOSE_CMD="docker-compose"
fi

info "Using docker compose command: ${DOCKER_COMPOSE_CMD:-(none)}"

# Start DB
info "Bringing up database container..."
if [ -n "$DOCKER_COMPOSE_CMD" ]; then
  $DOCKER_COMPOSE_CMD up -d $DB_SERVICE
else
  # fallback: run postgres container directly
  if docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
    if docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER_NAME}$"; then
      info "Database container already running"
    else
      info "Starting existing database container"
      docker start $DB_CONTAINER_NAME
    fi
  else
    info "Creating new database container: ${DB_CONTAINER_NAME}"
    docker run -d --name $DB_CONTAINER_NAME -e POSTGRES_USER=$DB_USER -e POSTGRES_PASSWORD=$DB_PASSWORD -e POSTGRES_DB=$DB_NAME -p ${DB_PORT}:5432 -v open-tms-db-data:/var/lib/postgresql/data postgres:16-alpine
  fi
fi

# Wait for DB readiness
info "Waiting for Postgres to become ready..."
MAX_ATTEMPTS=60
ATTEMPT=0
DB_CID=""
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  # try to find container id
  if [ -n "$DOCKER_COMPOSE_CMD" ]; then
    DB_CID=$($DOCKER_COMPOSE_CMD ps -q $DB_SERVICE 2>/dev/null || true)
  else
    DB_CID=$(docker ps -q -f name=$DB_CONTAINER_NAME || true)
  fi

  if [ -n "$DB_CID" ] && docker exec "$DB_CID" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
    info "Postgres is ready"
    break
  fi
  ATTEMPT=$((ATTEMPT+1))
  sleep 1
done
if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
  err "Postgres did not become ready in time"
  exit 1
fi

# Ensure node modules are installed (clean install to avoid optional-dep issues)
info "Preparing Node.js dependencies (this may take a minute)..."
if [ -d node_modules ] || [ -f package-lock.json ]; then
  info "Removing existing node_modules and package-lock.json to ensure a clean install"
  rm -rf node_modules package-lock.json
fi
npm install

# Backend migrations
info "Running Prisma / database migration steps"
export DATABASE_URL="$DATABASE_URL"

cd backend

info "Generating Prisma client"
npm run prisma:generate

info "Marking specific migration as applied if necessary (safe no-op if already applied)"
# This may fail harmlessly if migration was already resolved; ignore non-zero
DATABASE_URL=$DATABASE_URL npx prisma migrate resolve --applied 20260630_iot_vendors_webhook_secret --schema=prisma/schema.prisma || true

info "Applying remaining migrations"
DATABASE_URL=$DATABASE_URL npx prisma migrate deploy --schema=prisma/schema.prisma

info "Ensuring Prisma client is generated"
npm run prisma:generate

cd ..

# Build shared package so frontend can import it
info "Building packages/shared"
npm -w packages/shared run build

# Fresh install (ensure frontend tooling is properly installed)
info "Reinstalling top-level node modules to ensure native deps are present"
rm -rf node_modules package-lock.json || true
npm install

# Regenerate Prisma client after the clean install (the prior generate was
# wiped when root node_modules was removed)
info "Regenerating Prisma client after clean install"
cd backend
npm run prisma:generate
cd ..

# Seed the database with the comprehensive demo dataset
info "Seeding demo data (this will wipe existing demo data by default)"
npx tsx backend/src/scripts/comprehensive-seed.ts

info "Done. Demo credentials (from seed):"
cat <<'EOF'
  TMS admin:       admin@meridian-tms.demo       / Password1!
  TMS dispatcher:  dispatch@meridian-tms.demo    / Password1!
  TMS ops mgr:     ops-manager@meridian-tms.demo / Password1!
  TMS warehouse:   warehouse@meridian-tms.demo   / Password1!
  TMS finance:     finance@meridian-tms.demo     / Password1!
  Customer portal: admin@nordic.demo             / Portal123!
  Carrier portal:  dispatch@continental.demo     / Carrier123!
EOF

info "You can now run ./run.sh to start backend + frontend (or visit http://localhost:5173 if already running)."
