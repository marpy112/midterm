#!/usr/bin/env bash
# Part 1.2 - deploy the app WITHOUT Docker on an Ubuntu VM.
# Installs MongoDB, creates a database user, enables auth, installs the app
# under /opt with a systemd service, and closes everything but SSH and 3000.
#
#   sudo bash scripts/setup-vm-deployment.sh
#
# Tested on Ubuntu 26.04 (kernel 7.0). See the notes at the bottom for why the
# MongoDB version and repository codename are pinned the way they are.
set -euo pipefail

APP_USER=crudapp
APP_DIR=/opt/mongo-crud-api
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_NAME=crud_demo
DB_USER=crud_app
DB_PASS="${DB_PASS:-CrudVm2026}"
ENV_FILE=/etc/mongo-crud-api.env
MONGO_SERIES=8.2
APP_PORT=3000

step() { echo; echo "=============== $* ==============="; }

step "0/7  Free port $APP_PORT (stop the Docker deployment if it is running)"
if [ -f "$SRC_DIR/docker-compose.yml" ] && command -v docker >/dev/null 2>&1; then
  ( cd "$SRC_DIR" && docker compose down ) || true
fi

step "1/7  Install MongoDB $MONGO_SERIES"
curl -fsSL https://pgp.mongodb.com/server-8.0.asc \
  | gpg --yes --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/$MONGO_SERIES multiverse" \
  > "/etc/apt/sources.list.d/mongodb-org-$MONGO_SERIES.list"
apt-get update
apt-get install -y mongodb-org nodejs npm curl
systemctl enable --now mongod
sleep 5
systemctl is-active mongod || { journalctl -u mongod -n 20 --no-pager; exit 1; }
mongod --version | head -1

step "2/7  Create the application database user (before auth is switched on)"
mongosh --quiet <<JS
use $DB_NAME
if (db.getUser("$DB_USER")) { print("user already exists"); } else {
  db.createUser({ user: "$DB_USER", pwd: "$DB_PASS", roles: [{ role: "readWrite", db: "$DB_NAME" }] });
  print("user created");
}
JS

step "3/7  Enable authentication, keep MongoDB bound to 127.0.0.1"
grep -q "^security:" /etc/mongod.conf || printf "\nsecurity:\n  authorization: enabled\n" >> /etc/mongod.conf
grep -A2 "^net:" /etc/mongod.conf
systemctl restart mongod
sleep 5

step "4/7  Deploy the application to $APP_DIR"
id -u "$APP_USER" >/dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin "$APP_USER"
mkdir -p "$APP_DIR"
cp -r "$SRC_DIR"/. "$APP_DIR"/
rm -rf "$APP_DIR/.git" "$APP_DIR/.env"
cd "$APP_DIR"
npm ci --omit=dev
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

step "5/7  Configuration file - credentials outside the source tree"
cat > "$ENV_FILE" <<ENV
PORT=$APP_PORT
MONGODB_URI=mongodb://$DB_USER:$DB_PASS@127.0.0.1:27017/$DB_NAME?authSource=$DB_NAME
ENV
chown root:"$APP_USER" "$ENV_FILE"
chmod 640 "$ENV_FILE"
ls -l "$ENV_FILE"

step "6/7  systemd service"
cat > /etc/systemd/system/mongo-crud-api.service <<UNIT
[Unit]
Description=Mongo CRUD API
After=network-online.target mongod.service
Wants=network-online.target
Requires=mongod.service

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable mongo-crud-api
systemctl restart mongo-crud-api
sleep 6
systemctl is-active mongo-crud-api || { journalctl -u mongo-crud-api -n 30 --no-pager; exit 1; }

step "7/7  Firewall - only SSH and the app"
ufw allow OpenSSH
ufw allow $APP_PORT/tcp
ufw --force enable
ufw status verbose

step "Verify"
curl -s localhost:$APP_PORT/health; echo
curl -s -X POST localhost:$APP_PORT/api/tasks -H 'Content-Type: application/json' \
  -d '{"title":"deployed by hand on the VM"}' >/dev/null
curl -s localhost:$APP_PORT/api/tasks; echo
echo
echo "DONE - the database password is in $ENV_FILE (mode 640), never in the source."

# ---------------------------------------------------------------------------
# Notes for Ubuntu 26.04 (resolute):
#  * MongoDB publishes a "resolute" apt suite but it contains only
#    mongodb-database-tools - no server. The 24.04 (noble) suite is used
#    instead; its dependencies (libssl3t64, libcurl4t64, libc6) are satisfied.
#  * MongoDB 8.0.32 and 8.3.x refuse to start on Linux kernels >= 6.19
#    (SERVER-121912) and 26.04 ships kernel 7.0, so the 8.2 series is pinned.
# ---------------------------------------------------------------------------
