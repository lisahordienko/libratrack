#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

export JWT_SECRET="${JWT_SECRET:-replace-with-a-random-secret-before-running-the-api}"
export DATABASE_URL="${DATABASE_URL:-postgres://libratrack:libratrack@localhost:5432/libratrack?sslmode=disable}"
export PORT="${PORT:-8080}"

docker compose up -d postgres

until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-libratrack}" -d "${POSTGRES_DB:-libratrack}" >/dev/null 2>&1; do
  echo "Waiting for PostgreSQL..."
  sleep 1
done

echo "Starting LibraTrack at http://localhost:${PORT}"
go run ./cmd/api
