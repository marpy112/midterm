# 1.2 - Manual deployment on an Ubuntu VM

Everything installed by hand: Node.js runtime, MongoDB, the app, a systemd
service, and a firewall that opens only the ports actually used.

Works on any current Ubuntu LTS. The MongoDB step derives your release codename
automatically, so nothing needs editing by hand - verified on **Ubuntu 26.04
(resolute)** and **24.04 (noble)**.

---

## Step 0 - Create the VM

Use **Ubuntu Server 24.04 LTS** (not Ubuntu Desktop). It is a text console with
no graphical environment, so it idles at roughly 200-400 MB RAM and almost no
CPU - the difference between a VM you barely notice and one that makes the host
crawl. You will work in it over SSH from Windows Terminal anyway.

### Sizing for a modest host

Sensible on a 4-core / 16 GB machine:

| Setting | Value | Why |
| --- | --- | --- |
| RAM | **2048 MB** | 1024 MB runs, but MongoDB is happier with 2 GB |
| CPUs | **2** | Leave the rest of the cores to the host |
| Disk | **20 GB**, dynamically allocated | Only the space actually used is taken from the host |
| Video memory | 16 MB, no 3D acceleration | Nothing is being drawn |
| Audio | Disabled | Not needed |

Do **not** install Ubuntu Desktop / Lubuntu / Xubuntu for this. A desktop image
wants 4 GB and a compositor, and gives nothing the assignment needs.

### Windows host: check the hypervisor first

On Windows 10/11, if **Hyper-V**, **WSL2**, or **Virtual Machine Platform** is
enabled, VirtualBox is pushed into a slow compatibility mode:

```powershell
Get-ComputerInfo -Property HyperVisorPresent
```

If that reports `True` and the VM feels sluggish, either turn those Windows
features off (Control Panel -> Programs -> Turn Windows features on or off,
then reboot) or use VMware Workstation Player, which copes better. Also confirm
**VT-x / AMD-V** is enabled in the BIOS.

### What to download

| | Pick | Where |
| --- | --- | --- |
| Hypervisor | **VirtualBox 7.x** (free, no account) | https://www.virtualbox.org/wiki/Downloads -> *Windows hosts* |
| Guest OS | **Ubuntu Server 24.04 LTS** ISO (~3 GB) | https://ubuntu.com/download/server |

Download the **Server** ISO, not the Desktop one. VMware Workstation Player is a
fine substitute for VirtualBox if Hyper-V cannot be turned off (see above).

### Install

1. New VM -> Type *Linux*, Version *Ubuntu (64-bit)*, with the settings above.
2. Attach the Ubuntu Server 24.04 ISO and install. At the install-type prompt
   choose plain **"Ubuntu Server"** (not *minimized* - that strips editors and
   tools you will want), and tick **Install OpenSSH server** when offered.
3. Networking - pick one:
   - **Bridged adapter** (simplest): the VM gets its own IP on your LAN.
     Find it with `ip a`, then browse to `http://<vm-ip>:3000`.
   - **NAT + port forwarding**: Settings -> Network -> Advanced -> Port
     Forwarding, add `SSH 127.0.0.1:2222 -> 22` and `APP 127.0.0.1:3000 -> 3000`.
4. After installing, run it headless (right-click the VM -> Start -> **Headless
   Start**) and connect with `ssh <user>@<vm-ip>`. No VM window, less overhead.

### If the host is already tight on memory

A **free-tier cloud instance** uses none of your PC's resources and the
assignment allows it: Oracle Cloud Always Free, AWS EC2 t2.micro, or Azure B1s.
Launch Ubuntu 24.04 and allow only inbound **22** (from your IP) and **3000** in
the security group. Steps 1-9 below are otherwise identical.

---

## Step 1 - Base system

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl gnupg ca-certificates git ufw
```

## Step 2 - Install Node.js 22 (the runtime)

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
node -v && npm -v        # expect v22.x
```

## Step 3 - Install MongoDB 8.0 (the database)

MongoDB publishes its own apt repository per Ubuntu codename. `$(lsb_release -cs)`
fills in yours (`resolute` on 26.04, `noble` on 24.04), so these lines work
unchanged on either.

```bash
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | sudo gpg --yes --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg
```

```bash
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/8.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list
```

```bash
sudo apt update
sudo apt install -y mongodb-org
sudo systemctl enable --now mongod
sudo systemctl status mongod --no-pager
```

Check the repository resolved before installing - `apt update` must not report
`404 Not Found` for repo.mongodb.org. If it does, that codename has no packages
yet; substitute the previous LTS codename (`noble`) in the line above.

Note the `--yes` on `gpg --dearmor`: without it, gpg stops to ask whether to
overwrite an existing keyring and then silently waits for input.

## Step 4 - Secure MongoDB (auth on, bound to localhost)

Create an application user:

```bash
mongosh <<'JS'
use crud_demo
db.createUser({
  user: "crud_app",
  pwd: "PUT-A-STRONG-PASSWORD-HERE",
  roles: [{ role: "readWrite", db: "crud_demo" }]
})
JS
```

Turn on authentication and keep Mongo listening on loopback only:

```bash
sudo sed -i 's/^#\?\s*security:.*/security:\n  authorization: enabled/' /etc/mongod.conf
grep -A1 '^net:' /etc/mongod.conf      # bindIp must be 127.0.0.1
sudo systemctl restart mongod
```

Verify auth is enforced (this should now fail):

```bash
mongosh --quiet --eval 'db.getSiblingDB("crud_demo").tasks.find().toArray()'
```

## Step 5 - Deploy the app

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin crudapp
sudo mkdir -p /opt/mongo-crud-api
sudo chown crudapp:crudapp /opt/mongo-crud-api
```

Copy the project up (from your laptop, excluding node_modules):

```bash
rsync -av --exclude node_modules --exclude .env --exclude .git \
  ./mongo-crud-api/ <user>@<vm-ip>:/tmp/app/
```

Then on the VM:

```bash
sudo cp -r /tmp/app/. /opt/mongo-crud-api/
sudo chown -R crudapp:crudapp /opt/mongo-crud-api
cd /opt/mongo-crud-api
sudo -u crudapp npm ci --omit=dev
```

## Step 6 - Configuration (no passwords in source)

The connection string lives in a root-owned file readable only by the service
user - it is never committed and never appears in the code.

```bash
sudo tee /etc/mongo-crud-api.env >/dev/null <<'ENV'
PORT=3000
MONGODB_URI=mongodb://crud_app:PUT-A-STRONG-PASSWORD-HERE@127.0.0.1:27017/crud_demo?authSource=crud_demo
ENV

sudo chown root:crudapp /etc/mongo-crud-api.env
sudo chmod 640 /etc/mongo-crud-api.env
```

## Step 7 - systemd service

```bash
sudo tee /etc/systemd/system/mongo-crud-api.service >/dev/null <<'UNIT'
[Unit]
Description=Mongo CRUD API
After=network-online.target mongod.service
Wants=network-online.target
Requires=mongod.service

[Service]
Type=simple
User=crudapp
WorkingDirectory=/opt/mongo-crud-api
EnvironmentFile=/etc/mongo-crud-api.env
ExecStart=/usr/bin/node src/server.js
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now mongo-crud-api
sudo systemctl status mongo-crud-api --no-pager
journalctl -u mongo-crud-api -f
```

Expected log lines:

```
MongoDB connected: 127.0.0.1/crud_demo
API listening on http://localhost:3000
```

## Step 7b - If the Docker containers are already running

The container from part 1.3 also publishes port 3000, so the systemd service
cannot bind it. Stop the containers while demonstrating this deployment:

```bash
cd ~/midterm && docker compose down
```

Bring them back afterwards on a different port so both can run at once:

```bash
cd ~/midterm && echo "APP_PORT=8080" >> .env && docker compose up -d
```

## Step 8 - Firewall: only the ports you actually need

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH        # 22  - administration
sudo ufw allow 3000/tcp       # 3000 - the app
sudo ufw enable
sudo ufw status verbose
```

**27017 is deliberately not opened.** MongoDB is bound to `127.0.0.1`, so only
the app on the same VM can reach it.

## Step 9 - Verify

```bash
# on the VM
curl -s localhost:3000/health
curl -s -X POST localhost:3000/api/tasks \
  -H 'Content-Type: application/json' -d '{"title":"from the VM"}'
curl -s localhost:3000/api/tasks

# from your laptop
curl http://<vm-ip>:3000/health
```

Then open `http://<vm-ip>:3000` in a browser for the UI.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `Could not connect to MongoDB` | `sudo systemctl status mongod`; confirm user/password in `/etc/mongo-crud-api.env` |
| Service restarts in a loop | `journalctl -u mongo-crud-api -n 50` |
| Reachable on the VM but not from the laptop | `sudo ufw status`; cloud security group; VirtualBox port forwarding |
| `Authentication failed` | `authSource` must match the db the user was created in (`crud_demo`) |
