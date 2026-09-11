# mongo-crud-api

A simple CRUD REST API built with **Express + Mongoose (MongoDB)**, plus a tiny
HTML page to exercise it in the browser. The resource is a `Task`.

## Setup

```bash
npm install
cp .env.example .env    # then edit MONGODB_URI if needed
npm start
```

Open http://localhost:3000 for the mini UI, or hit the API directly.

You need a MongoDB to point at. Either:

- **Local**: install MongoDB Community Server and use
  `mongodb://127.0.0.1:27017/crud_demo`
- **Docker**: `docker run -d -p 27017:27017 --name mongo mongo:7`
- **Atlas** (free cloud tier): paste the connection string into `MONGODB_URI`

Optional sample data: `npm run seed` (this wipes the `tasks` collection first).

## Scripts

| Command | What it does |
| --- | --- |
| `npm start` | Run the API |
| `npm run dev` | Run with auto-restart on file changes |
| `npm run seed` | Replace the collection with 3 sample tasks |

## Data model

```js
{
  title:       String,   // required, max 120 chars
  description: String,   // optional, max 1000 chars
  status:      String,   // 'todo' | 'in-progress' | 'done'  (default 'todo')
  dueDate:     Date,     // optional
  createdAt:   Date,     // auto
  updatedAt:   Date      // auto
}
```

## Endpoints

| Method | Path | Description |
| --- | --- | --- |
| GET | `/health` | Service + DB connection status |
| POST | `/api/tasks` | Create a task |
| GET | `/api/tasks` | List tasks (`?status=`, `?search=`, `?page=`, `?limit=`) |
| GET | `/api/tasks/:id` | Get one task |
| PUT / PATCH | `/api/tasks/:id` | Update a task |
| DELETE | `/api/tasks/:id` | Delete a task (204, no body) |

Successful responses wrap the payload in `data`; list responses add `meta`
with `total`, `page`, `limit`, `pages`. Errors return `{ "error": "..." }`,
and validation errors add a `details` array.

### Examples

```bash
# Create
curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Buy milk","description":"2%","status":"todo"}'

# List (filter + search)
curl "http://localhost:3000/api/tasks?status=todo&search=milk&page=1&limit=10"

# Read one
curl http://localhost:3000/api/tasks/<id>

# Update
curl -X PATCH http://localhost:3000/api/tasks/<id> \
  -H "Content-Type: application/json" \
  -d '{"status":"done"}'

# Delete
curl -X DELETE http://localhost:3000/api/tasks/<id>
```

## Deployment

This app is deployed two ways, from the same source tree:

| | Guide | Summary |
| --- | --- | --- |
| **VM** | [DEPLOY-VM.md](DEPLOY-VM.md) | Ubuntu VM, everything installed by hand: Node 22, MongoDB 7 with auth, a `crudapp` system user, a systemd unit, and `ufw` allowing only 22 and 3000 |
| **Docker** | [DEPLOY-DOCKER.md](DEPLOY-DOCKER.md) | `Dockerfile` + `docker-compose.yml`; app and database come up together with `docker compose up --build` |

### Configuration

No credential is ever written in the source. `MONGODB_URI` is read from the
environment at startup ([src/config/env.js](src/config/env.js)):

- **local dev** - a gitignored `.env` file
- **VM** - `/etc/mongo-crud-api.env`, mode `640`, loaded by systemd
- **Docker** - compose interpolates `MONGO_ROOT_PASSWORD` from `.env` into the
  connection string at runtime; it is not baked into the image


## Layout

```
src/
  server.js               entry point: connect DB, listen, graceful shutdown
  app.js                  express app wiring (middleware, routes)
  config/db.js            mongoose connection helpers
  models/Task.js          schema + validation
  controllers/taskController.js   create / list / get / update / delete
  routes/taskRoutes.js    REST route table
  middleware/errorHandler.js      404 + central error formatting
  seed.js                 sample data
public/index.html         minimal browser UI for the API
```

## Notes

- Errors are handled centrally: Mongoose `ValidationError` → 400 with field
  messages, malformed ObjectIds → 400, missing documents → 404.
- `SIGINT`/`SIGTERM` close the HTTP server and the Mongo connection cleanly.

## Assignment mapping (Part 1)

| Requirement | Where |
| --- | --- |
| 1.1 CRUD app on a simple resource | `Task` resource - create / read / list / update / delete in [src/controllers/taskController.js](src/controllers/taskController.js) |
| 1.1 Connects to a real database | MongoDB via Mongoose ([src/config/db.js](src/config/db.js)) |
| 1.1 No hard-coded database password | `MONGODB_URI` read from the environment; `.env` is gitignored and excluded from the Docker build context |
| 1.2 Ubuntu VM, installed by hand | [DEPLOY-VM.md](DEPLOY-VM.md) steps 1-7 |
| 1.2 Only the needed ports open | `ufw` allows 22 and 3000; MongoDB bound to `127.0.0.1`, 27017 never opened (step 8) |
| 1.3 Own Dockerfile | [Dockerfile](Dockerfile) - multi-stage, non-root, healthcheck |
| 1.3 docker-compose, app + db together | [docker-compose.yml](docker-compose.yml) - `app` + `mongo`, private network, named volume |
| 1.3 Works from a clean build | `docker compose down -v && docker compose build --no-cache && docker compose up` ([DEPLOY-DOCKER.md](DEPLOY-DOCKER.md)) |
