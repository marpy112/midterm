#!/usr/bin/env bash
# Part 2.1 - collect resource and startup numbers from both deployments.
#
#   ./scripts/measure.sh vm        # the by-hand systemd deployment
#   ./scripts/measure.sh docker    # the container deployment
#
# Run each on the machine hosting that deployment and paste the output into the
# report. Both modes measure the same three things the question asks for:
# memory, CPU, and cold-start time to a working HTTP response.
set -uo pipefail

MODE="${1:-}"
PORT="${2:-}"

# Wait until /health answers, printing how long that took. This is the honest
# definition of "started": the process is up AND the database is reachable.
time_to_healthy() {
  local port="$1" start now
  start=$(date +%s.%N)
  for _ in $(seq 1 600); do
    if curl -fsS "http://localhost:$port/health" >/dev/null 2>&1; then
      now=$(date +%s.%N)
      awk -v a="$start" -v b="$now" 'BEGIN{printf "%.1f", b-a}'
      return 0
    fi
    sleep 0.1
  done
  echo "TIMEOUT"
  return 1
}

hr() { echo; echo "----- $* -----"; }

case "$MODE" in
vm)
  PORT="${PORT:-3000}"
  hr "Host"
  echo "Kernel:  $(uname -r)"
  echo "CPUs:    $(nproc)"
  free -m | awk 'NR==1||NR==2'

  hr "Idle memory of the whole VM (nothing to subtract - the VM IS the overhead)"
  free -m | awk '/Mem:/ {printf "used=%s MB  free=%s MB  available=%s MB\n", $3, $4, $7}'

  hr "Resident memory per process"
  ps -o rss=,comm=,args= -C node -C mongod 2>/dev/null \
    | awk '{rss=$1/1024; $1=""; printf "%8.1f MB  %s\n", rss, $0}'
  echo "(node = the app, mongod = the database; both installed directly on the VM)"

  hr "CPU, 5s sample while idle"
  top -bn2 -d5 | awk '/^%Cpu/ {line=$0} END {print line}'

  hr "Cold start: systemctl restart -> first successful /health"
  sudo systemctl stop mongo-crud-api
  sleep 2
  sudo systemctl start mongo-crud-api
  echo "app only (database already running):  $(time_to_healthy "$PORT") s"

  hr "Cold start including the database"
  sudo systemctl stop mongo-crud-api mongod
  sleep 2
  sudo systemctl start mongod mongo-crud-api
  echo "database + app:                       $(time_to_healthy "$PORT") s"

  hr "Full VM boot, for reference"
  systemd-analyze 2>/dev/null || echo "(systemd-analyze unavailable)"

  hr "Disk footprint"
  du -sh /opt/mongo-crud-api 2>/dev/null
  du -sh /var/lib/mongodb 2>/dev/null
  ;;

docker)
  PORT="${PORT:-${APP_PORT:-3000}}"
  cd "$(dirname "${BASH_SOURCE[0]}")/.."

  hr "Host / engine"
  docker version --format 'client {{.Client.Version}}  server {{.Server.Version}}'
  docker info --format 'CPUs={{.NCPU}}  Memory={{.MemTotal}} bytes  Driver={{.Driver}}'

  hr "Cold start from a clean build (images cached, volume wiped)"
  docker compose down -v >/dev/null 2>&1
  start=$(date +%s.%N)
  docker compose up -d >/dev/null
  up=$(date +%s.%N)
  echo "compose up returned after:            $(awk -v a="$start" -v b="$up" 'BEGIN{printf "%.1f", b-a}') s"
  echo "...to first successful /health:       $(time_to_healthy "$PORT") s"
  echo "(total wall clock from 'up' to a working API)"

  hr "Warm restart, for comparison with the VM's systemctl restart"
  docker compose restart app >/dev/null
  echo "restart app -> /health:               $(time_to_healthy "$PORT") s"

  hr "Memory and CPU per container"
  docker stats --no-stream --format \
    'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'

  hr "Image sizes (what you actually ship)"
  docker image ls --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' \
    | grep -Ei 'mongo|crud|REPOSITORY'

  hr "Build time from scratch (no cache) - run separately, this is slow"
  echo "  docker compose build --no-cache   # time it yourself"

  hr "Proof the database port is not exposed"
  # An unpublished port inspects as null; a published one lists a HostPort.
  mongo_ports=$(docker inspect -f '{{json .NetworkSettings.Ports}}'     "$(docker compose ps -q mongo)" 2>/dev/null)
  case "$mongo_ports" in
    *HostPort*) echo "WARNING - mongo publishes a host port: $mongo_ports" ;;
    *)          echo "mongo publishes no host port ($mongo_ports)" ;;
  esac
  docker compose exec -T app sh -c 'nc -z mongo 27017 && echo "app CAN reach mongo:27017 (expected)"' 2>/dev/null
  ;;

*)
  echo "usage: $0 {vm|docker} [port]" >&2
  exit 1
  ;;
esac

hr "Done"
