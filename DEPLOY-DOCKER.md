# 1.3 - Docker deployment

The same application image, plus MongoDB, brought up together with one command.

## Files

| File | Role |
| --- | --- |
| `Dockerfile` | Builds the app image: two stages, production dependencies only, runs as the non-root `node` user, `HEALTHCHECK` against `/health` |
| `.dockerignore` | Keeps `node_modules`, `.git` and **`.env`** out of the build context |
| `docker-compose.yml` | Two services - `app` and `mongo` - on a private network, with a named volume for the data |

## Run it from a clean build

```bash
cd mongo-crud-api
cp .env.example .env          # then set MONGO_ROOT_PASSWORD to something real
docker compose up --build
```

Open http://localhost:3000

```bash
docker compose ps             # both services, mongo marked healthy
docker compose logs -f app
docker compose down           # stop
docker compose down -v        # stop and delete the database volume
```

## How the pieces fit

- **Startup order** - `app` declares `depends_on: mongo: condition: service_healthy`,
  so it only starts after Mongo answers `db.adminCommand('ping')`. No sleep loops.
- **Networking** - compose puts both services on a private network where the app
  reaches the database at the hostname `mongo`. The `mongo` service publishes
  **no ports**, so the database is not reachable from the host or the network;
  only the app's port 3000 is published.
- **Persistence** - the named volume `mongo-data` holds `/data/db`, so data
  survives `docker compose down` and rebuilds.
- **Credentials** - `MONGO_ROOT_USER` / `MONGO_ROOT_PASSWORD` come from your
  local `.env`, which compose interpolates into `MONGODB_URI` at runtime.
  Nothing is baked into the image and nothing is in the source code. Compose
  refuses to start if `MONGO_ROOT_PASSWORD` is unset.

## Proving it works from a clean build

```bash
docker compose down -v                # wipe everything
docker compose build --no-cache
docker compose up -d
sleep 20
curl -s localhost:3000/health
curl -s -X POST localhost:3000/api/tasks \
  -H 'Content-Type: application/json' -d '{"title":"from docker"}'
curl -s localhost:3000/api/tasks
```

Restart-persistence check (good screenshot for the report):

```bash
docker compose restart
curl -s localhost:3000/api/tasks       # the task is still there
```

## Verifying the database is not exposed

```bash
docker compose port mongo 27017        # expect: no published port
nc -zv localhost 27017                 # expect: connection refused
```
