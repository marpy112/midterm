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

---

## Running the containers inside the Ubuntu VM

Docker can run inside the same VM used for 1.2, which avoids installing Docker
Desktop on Windows. Every command below is a single line - do not paste
multi-line commands into the VM console, the line continuations get mangled.

### 1. Install Docker from Ubuntu's own repositories

No third-party apt repository, so this works on any Ubuntu release:

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 git
```

If `docker-compose-v2` is not found on your release, use Docker's installer
script instead:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

Allow your user to run docker without `sudo`:

```bash
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world
```

### 2. Get the code and configure

```bash
git clone https://github.com/marpy112/midterm.git
cd midterm
cp .env.example .env
sed -i 's/change-me/ChangeThisPassword123/' .env
```

### 3. Build and run

```bash
docker compose up --build -d
docker compose ps
docker compose logs -f app
```

### 4. Verify from inside the VM

```bash
curl -s localhost:3000/health
curl -s -X POST localhost:3000/api/tasks -H 'Content-Type: application/json' -d '{"title":"from docker in the VM"}'
curl -s localhost:3000/api/tasks
```

### Running both deployments on one VM

The systemd service from 1.2 and the container both want port 3000. Either stop
one while demonstrating the other:

```bash
sudo systemctl stop mongo-crud-api
```

or publish the container on a different port, which `docker-compose.yml` already
supports:

```bash
echo "APP_PORT=8080" >> .env
docker compose up -d
sudo ufw allow 8080/tcp
```

### Reaching it from the Windows browser

With the VM on NAT, add port forwarding on the Windows host (VM must be
running, or set it in Settings -> Network -> Advanced -> Port Forwarding):

```
VBoxManage controlvm "CRUD" natpf1 "app,tcp,127.0.0.1,3000,,3000"
VBoxManage controlvm "CRUD" natpf1 "ssh,tcp,127.0.0.1,2222,,22"
```

Then browse to http://localhost:3000 on Windows, or `ssh -p 2222 <user>@127.0.0.1`.
Switching the adapter to **Bridged** instead gives the VM its own LAN IP and
needs no forwarding.
