# Demo Script — MIT001.26 Midterm

CRUD app, gi-deploy sa duha ka paagi: Ubuntu VM ug Docker.
**Bold** = isulti. Code block = i-run.

Target: 8 minutes.

---

## 1. Intro (20 sec)

> **"Kami si [names]. Among gihimo kay CRUD REST API — Node.js, Express,
> MongoDB. Gi-deploy namo ang parehas nga app sa duha ka paagi: manual sa
> Ubuntu VM, ug sa Docker containers."**

---

## 2. Walay hardcoded password (30 sec)

```bash
git log --all -S "mongodb+srv" --oneline
```

> **"Requirement nga dili naka-hardcode ang password. Walay resulta — wala gyud
> na-commit ang credentials sa tibuok history."**

---

## 3. VM Deployment (3 min)

### Start ang VM

```bash
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "CRUD" --type headless
```

```bash
ssh -p 2222 <username>@127.0.0.1
```

> **"Naa ta sa sulod sa VM. Tanan diri manual namong gi-install."**

### Ipakita nga tinuod

```bash
systemctl status mongod --no-pager
systemctl status mongo-crud-api --no-pager
```

> **"Duha ka systemd services. Ang MongoDB gi-install direkta sa VM, dili
> container. Ang app nagdagan isip systemd service."**

### Security

```bash
sudo ufw status verbose
```

> **"Port 22, 3000, ug 8080 ra ang abli. Ang 27017 — ang MongoDB port — wala
> gi-abli, kay naka-bind ra siya sa localhost."**

```bash
ls -l /etc/mongo-crud-api.env
```

> **"Ang password naa diri, mode 640, owned by root. Dili sa source code."**

### CRUD cycle

```bash
cd ~/midterm && ./scripts/demo.sh 3000
```

Press Enter kada step. Isulti kada isa:

- **"Health check — connected ang database."**
- **"CREATE — naa nay bag-ong task."**
- **"READ — makita na siya sa listahan."**
- **"UPDATE — done na ang status."**
- **"Validation — kung walay title, mo-reject, 400."**
- **"DELETE — 204. Unya 404 na. Wala na gyud."**

---

## 4. Docker Deployment (3 min)

### Dockerfile

```bash
cat Dockerfile
```

> **"Multi-stage build. Duha ka importante: ang `USER node` — dili modagan as
> root. Ug ang `HEALTHCHECK` — automatic mo-check ang Docker kung buhi ang app."**

### Compose

```bash
cat docker-compose.yml
```

> **"Ang `mongo` service walay `ports` section — dili siya ma-abot gikan sa
> gawas, ang app container ra. Sa VM kinahanglan pa namo i-configure ang
> bindIp ug ufw para makuha ang parehas. Diri, default na."**

### Build ug run

```bash
docker compose up -d --build
```

> **"Usa ra ka command para sa app ug database."**

```bash
docker compose ps
```

> **"Duha ka containers, pareho healthy. Ang `depends_on` naka-set sa
> `service_healthy` — dili mo-start ang app hangtod ready ang MongoDB."**

### Proof nga dili exposed ang DB

```bash
docker inspect -f "{{json .NetworkSettings.Ports}}" mongo-crud-api-mongo-1
```

> **"Null — walay published port."**

```bash
docker compose exec app sh -c "nc -z mongo 27017 && echo REACHABLE"
```

> **"Pero gikan sa app container, ma-abot. Mao gyud ni ang gusto."**

### CRUD cycle

```bash
./scripts/demo.sh 8080
```

> **"Parehas nga script, parehas nga app — container na karon. Mo-gana gihapon."**

---

## 5. Side by side (30 sec)

**Pinaka-importante ni nga part.**

```bash
curl -s localhost:3000/health
curl -s localhost:8080/health
```

> **"Duha ka deployments, dungan nga nagdagan. Ang 3000 kay ang VM. Ang 8080 kay
> ang Docker. Parehas ra nga source code."**

---

## 6. Persistence (30 sec)

```bash
curl -s -X POST localhost:8080/api/tasks -H "Content-Type: application/json" -d "{\"title\":\"survives a rebuild\"}"
docker compose down
docker compose up -d
curl -s localhost:8080/api/tasks
```

> **"Gi-down unya gi-up balik — naa gihapon ang data, kay naa sa named volume.
> Pero kung `down -v` — dash V — mawala ang volume ug mawala ang data. Usa ra
> ka letter, pero dako ang epekto."**

---

## 7. Comparison (1 min)

| | VM | Docker |
|---|---|---|
| App memory | *(imong number)* | 35.6 MiB |
| DB memory | *(imong number)* | 179.1 MiB |
| Cold start | *(imong number)* | 8.4 s |
| Rebuild | *(imong number)* | 22.3 s |

> **"Mas gamay og RAM ug mas paspas ang Docker kay gi-share ra niya ang kernel
> sa host. Ang VM, naa gyuy tibuok OS nga i-boot."**
>
> **"Pero mas lig-on ang security sa VM — kung ma-compromise ang container,
> ang host mismo delikado kay usa ra man ang kernel."**

---

## 8. Closing (20 sec)

> **"Gi-build namo ang CRUD app nga naka-connect sa tinuod nga MongoDB, walay
> hardcoded password, ug gi-deploy sa duha ka paagi. Parehas silang nagdagan."**
>
> **"Mas sayon ang Docker mag-update ug mag-move. Mas lig-on ang isolation sa
> VM. Salamat — ready mi sa mga pangutana."**

---

## Cheat sheet

```bash
# VM
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" startvm "CRUD" --type headless
ssh -p 2222 <username>@127.0.0.1
systemctl status mongod --no-pager
systemctl status mongo-crud-api --no-pager
sudo ufw status verbose
ls -l /etc/mongo-crud-api.env
cd ~/midterm && ./scripts/demo.sh 3000

# Docker
cat Dockerfile
cat docker-compose.yml
docker compose up -d --build
docker compose ps
docker inspect -f "{{json .NetworkSettings.Ports}}" mongo-crud-api-mongo-1
docker compose exec app sh -c "nc -z mongo 27017 && echo REACHABLE"
./scripts/demo.sh 8080

# Side by side
curl -s localhost:3000/health
curl -s localhost:8080/health

# Persistence
docker compose down && docker compose up -d && curl -s localhost:8080/api/tasks
```

**Kung mag-crash:** port occupied → `netstat -ano | findstr :3000` unya
`taskkill /PID <pid> /F`. Dugay mo-build → pre-build before recording.
