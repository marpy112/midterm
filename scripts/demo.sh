#!/usr/bin/env bash
# Interactive CRUD walkthrough, for demonstrating either deployment.
#   ./scripts/demo.sh 3000   -> the by-hand (systemd) deployment
#   ./scripts/demo.sh 8080   -> the Docker deployment
PORT="${1:-3000}"
API="http://localhost:$PORT/api/tasks"
[ "$PORT" = "8080" ] && LABEL="DOCKER deployment" || LABEL="BY-HAND (systemd) deployment"

pretty() { python3 -m json.tool 2>/dev/null || cat; }
pause()  { echo; read -rp "   [Enter] to continue..." _; echo; }

clear
echo "############################################################"
echo "#  CRUD demo - $LABEL   (port $PORT)"
echo "############################################################"

echo
echo ">>> Health check: is the app up and connected to MongoDB?"
echo "    curl http://localhost:$PORT/health"
curl -s "http://localhost:$PORT/health" | pretty
pause

echo ">>> CREATE - POST a new task"
echo "    curl -X POST $API -d '{\"title\":\"Demo task\",...}'"
ID=$(curl -s -X POST "$API" -H 'Content-Type: application/json' \
      -d '{"title":"Demo task","description":"created during the demo","status":"todo"}' \
      | tee /dev/stderr | grep -o '"id":"[^"]*' | cut -d'"' -f4)
echo
echo "    -> new id: $ID"
pause

echo ">>> READ - list all tasks"
echo "    curl $API"
curl -s "$API" | pretty
pause

echo ">>> READ ONE - fetch that task by id"
echo "    curl $API/$ID"
curl -s "$API/$ID" | pretty
pause

echo ">>> UPDATE - mark it done"
echo "    curl -X PATCH $API/$ID -d '{\"status\":\"done\"}'"
curl -s -X PATCH "$API/$ID" -H 'Content-Type: application/json' -d '{"status":"done"}' | pretty
pause

echo ">>> VALIDATION - a task with no title must be rejected"
echo "    curl -X POST $API -d '{}'"
curl -s -X POST "$API" -H 'Content-Type: application/json' -d '{}' | pretty
pause

echo ">>> DELETE - remove the task"
echo "    curl -X DELETE $API/$ID"
curl -s -o /dev/null -w "    HTTP %{http_code}  (204 = deleted, no content)\n" -X DELETE "$API/$ID"
echo
echo ">>> CONFIRM - fetching it again must 404"
curl -s -o /dev/null -w "    HTTP %{http_code}  (404 = gone)\n" "$API/$ID"
echo
echo "############################################################"
echo "#  Demo complete - create, read, update, delete all working"
echo "############################################################"
