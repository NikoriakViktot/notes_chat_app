# Docker: A Complete Practical Guide

> **Module 3 — Python Advanced · Viktor Nikoriak**  
> An experienced engineer's guide to Docker: mental models, architecture, real-world workflows, and production patterns.

---

## Contents

0. [Installing Docker](#0-installing-docker)
1. [What Docker Is (the mental model)](#1-what-docker-is-the-mental-model)
2. [Core Concepts](#2-core-concepts)
3. [Architecture Overview](#3-architecture-overview)
4. [The Docker Workflow (the real lifecycle)](#4-the-docker-workflow-the-real-lifecycle)
5. [Essential Docker Commands](#5-essential-docker-commands)
6. [Docker Compose (multi-container systems)](#6-docker-compose-multi-container-systems)
7. [Volumes and Data Persistence](#7-volumes-and-data-persistence)
8. [Networking](#8-networking)
9. [Common Mistakes](#9-common-mistakes)
10. [Best Practices](#10-best-practices)
11. [Official Images for the Python Advanced Course](#11-official-images-for-the-python-advanced-course)

---

## 0. Installing Docker

The official page for downloading and installing Docker Desktop (Windows, macOS, Linux):

> **[https://www.docker.com/](https://www.docker.com/)**

### Installation steps (Windows / macOS)

1. Go to [https://www.docker.com/](https://www.docker.com/)
2. Click **"Download Docker Desktop"**
3. Run the installer and follow the instructions
4. After installation, verify:

```bash
docker --version
# Docker version 26.x.x, build ...

docker compose version
# Docker Compose version v2.x.x
```

### First check

```bash
docker run hello-world
# If you see "Hello from Docker!" — the installation succeeded
```

### Docker Hub — the image registry

After installing Docker, sign up at **[Docker Hub](https://hub.docker.com/)** — the main public registry of Docker images.

```bash
docker login               # log in to Docker Hub from the terminal
docker logout              # log out
```

Docker Hub contains official images for:
- **Languages**: `python`, `node`, `golang`, `java`
- **Databases**: `postgres`, `mysql`, `redis`, `mongodb`
- **Web servers**: `nginx`, `traefik`, `caddy`
- **Your own applications**: uploaded with the `docker push` command

---

## 1. What Docker Is (the mental model)

### The problem Docker solves

Before Docker, deploying software meant constantly answering the question:

> *"It works on my machine — why does it crash on the server?"*

The answer was always the same: **the environment is different**. A different OS, different library versions, different system dependencies, different Python paths.

Docker solves this by packaging not just your code — but **the entire runtime environment** your code depends on.

### The right mental model: the shipping container

Before containerized shipping, cargo was loaded onto ships as individual items. Loading and unloading was slow, unreliable, and different in every port.

The invention of the **standardized shipping container** changed everything:
- **The same container** fits any ship, truck, or crane
- The contents don't depend on the vehicle
- The vehicle doesn't depend on the contents

Docker is exactly that, but for software:

| Physical shipping | Docker |
|---------------------|--------|
| Shipping container | Docker container |
| Goods inside | Your application + dependencies |
| Ship / truck | Any server with Docker |
| Port infrastructure | Docker daemon |
| Container specification standard | OCI (Open Container Initiative) |

### What Docker is NOT

Docker is **not** a virtual machine. This is the most common misconception.

```
Virtual machine:                  Docker container:

┌─────────────────────┐           ┌─────────────────────┐
│    Your app         │           │    Your app         │
├─────────────────────┤           ├─────────────────────┤
│    Guest OS         │           │    Libs/Deps        │
│    (full Linux/Win) │           │    (no OS kernel!)  │
├─────────────────────┤           ├─────────────────────┤
│    Hypervisor       │           │    Docker Engine    │
├─────────────────────┤           ├─────────────────────┤
│    Host OS          │           │  Host OS (shared)   │
├─────────────────────┤           ├─────────────────────┤
│    Physical hardware│           │    Physical hardware│
└─────────────────────┘           └─────────────────────┘

Size: ~1–10 GB                    Size: ~10–500 MB
Startup: ~30–60 sec               Startup: ~0.1–2 sec
```

**The key difference:** Containers share the **host OS kernel**. They don't emulate hardware. That makes them much faster and lighter than VMs.

### Why Docker: three axes of pain

| Pain | Without Docker | With Docker |
|------|-----------|----------|
| **Environment drift** | "It works on my machine" | An identical environment everywhere |
| **Dependency hell** | Python 3.8 vs 3.11 conflicts | Each app has its own isolated libraries |
| **Deployment complexity** | Ansible scripts, SSH, manual steps | `docker run` on any machine |

---

## 2. Core Concepts

### 2.1 Image

**Definition:** A Docker image is an **immutable, layered filesystem snapshot** that contains everything needed to run an application: OS libraries, the runtime, dependencies, application code, and the startup command.

**Mental model:** An image is a **recipe** (or a class in OOP). It defines what a container will look like, but doesn't run anything by itself.

**Role in the system:**
- Built once, run many times
- Stored in registries (Docker Hub, AWS ECR, GitHub Container Registry)
- Identified by name + tag: `python:3.11-slim`, `nginx:1.25`, `myapp:v2.3`

**Relationship to the others:**
- `Dockerfile` → builds → `Image`
- `Image` → is instantiated into → `Container`
- Images consist of **layers** — every `RUN`, `COPY`, `ADD` instruction in a Dockerfile creates a new layer

```
Image layer architecture:

Layer 4: COPY app/ /app          ← your code (changes often)
Layer 3: RUN pip install -r ...  ← dependencies (change sometimes)
Layer 2: RUN apt-get install ... ← system libraries (rarely change)
Layer 1: FROM python:3.11-slim   ← base image (shared between images)
```

Layers are **cached and shared**. If layers 1–3 haven't changed, Docker reuses them — only layer 4 is rebuilt. That's why **layer order matters**.

---

### 2.2 Container

**Definition:** A container is a **running instance of an image**. It is an isolated process on the host OS with its own filesystem, network interface, and process space.

**Mental model:** If an image is a class, then a container is an **object** — an instance created from that class. You can create many containers from one image.

**Role in the system:**
- Runs the actual workload
- Has a **writable layer** on top of the immutable image layers
- Is **ephemeral** by default — after it is stopped and removed, all written data is lost
- Has a lifecycle: `created → running → paused → stopped → removed`

```
Container = Image layers (immutable) + Writable layer (ephemeral)

┌──────────────────────────────────┐
│  Writable layer (container data) │ ← lost on rm
├──────────────────────────────────┤
│  Image layer 4: app code         │ ← read-only
│  Image layer 3: pip packages     │ ← read-only
│  Image layer 2: system libs      │ ← read-only
│  Image layer 1: base OS          │ ← read-only (shared)
└──────────────────────────────────┘
```

---

### 2.3 Volume

**Definition:** A Docker volume is a **managed storage mechanism** that lives outside the container's writable layer. Data in a volume persists even after the container is removed.

**Mental model:** A volume is a **USB flash drive** that you plug into a container. The container can be deleted, but the USB drive — and its data — remains.

**Role in the system:**
- Stores persistent data: databases, uploaded files, logs
- Can be shared between several containers
- Managed by Docker (stored in `/var/lib/docker/volumes/` on Linux)

**Types:**

| Type | Syntax | Use case |
|-----|-----------|----------------------|
| **Named volume** | `mydata:/app/data` | Production databases, persistent app data |
| **Bind mount** | `/host/path:/container/path` | Development — live code reloading |
| **tmpfs mount** | `--tmpfs /app/cache` | Sensitive data that must not reach the disk |

---

### 2.4 Network

**Definition:** A Docker network is a **virtual networking layer** that lets containers communicate with each other and with the outside world.

**Mental model:** A network is a **private office LAN**. Containers on the same network can reach each other by service name (like a hostname). Containers on different networks are isolated.

**Role in the system:**
- Enables communication between services (API → Database)
- Isolates environments (production and staging containers don't see each other)
- Controls what is reachable from the host machine (published ports)

**Built-in network drivers:**

| Driver | Description |
|---------|------|
| `bridge` | The default. An isolated virtual network on the host. Containers communicate by service name |
| `host` | The container uses the host's network stack. No isolation — rarely used |
| `none` | No network. Full isolation |
| `overlay` | Multi-host networking. Used in Docker Swarm / Kubernetes |

---

## 3. Architecture Overview

```mermaid
flowchart TD
    User(["Developer / CI Pipeline"])
    CLI["Docker CLI<br>docker build / run / push"]
    Daemon["Docker Daemon<br>dockerd"]
    Registry[("Docker Registry<br>Hub / ECR / GHCR")]
    Images[("Images<br>immutable layers")]
    Containers[("Containers<br>running processes")]
    Volumes[("Volumes<br>persistent storage")]
    Networks[("Networks<br>virtual LANs")]

    User --> CLI
    CLI -->|REST API / Unix socket| Daemon
    Daemon -->|push / pull| Registry
    Daemon --> Images
    Daemon -->|instantiates| Containers
    Containers -->|mounts| Volumes
    Containers -->|connects to| Networks
    Images -->|immutable base for| Containers

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class User,CLI,Registry step;
    class Images,Containers,Volumes,Networks success;
    class Daemon warning;
```

### Diagram explanation

**1. Developer → Docker CLI**  
Every Docker command (`docker build`, `docker run`, `docker ps`) is handled by the **Docker CLI** — the client tool. The CLI itself doesn't do the heavy lifting.

**2. Docker CLI → Docker Daemon**  
The CLI talks to the **Docker Daemon** (`dockerd`) via a REST API over a Unix socket (`/var/run/docker.sock`). The daemon is the background service that actually manages everything. That's why you sometimes get "permission denied" errors — you need access to this socket.

**3. Daemon → Registry**  
When you run `docker pull python:3.11` or `docker push myapp:v2`, the daemon connects to a **registry** — a remote image store. Docker Hub is the default public registry. Companies use private registries (AWS ECR, GitHub Container Registry).

**4. Images → Containers**  
The daemon uses images as immutable base layers. When a container starts, Docker adds a thin writable layer on top of the image layers.

**5. Containers → Volumes & Networks**  
Running containers interact with the outside world through:
- **Volumes** — for reading/writing persistent data
- **Networks** — for talking to other containers or publishing ports on the host

---

## 4. The Docker Workflow (the real lifecycle)

```mermaid
flowchart LR
    Code(["Write code<br>+ Dockerfile"])
    Build(["docker build<br>Create the Image"])
    Image[("Image<br>v1.0")]
    Run(["docker run<br>Start the container"])
    Container(["Running<br>container"])
    Debug(["Debug<br>docker logs / exec"])
    Fix(["Fix the code"])
    Push(["docker push<br>To the registry"])
    Registry[("Registry<br>Hub / ECR")]

    Code --> Build --> Image --> Run --> Container
    Container --> Debug --> Fix --> Build
    Image --> Push --> Registry

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Code,Build,Run,Push,Fix step;
    class Image,Container,Registry success;
    class Debug warning;
```

### Step by step: a developer's real process

**Step 1 — Write code + Dockerfile**

You write your application AND a `Dockerfile` that describes how to package it. The Dockerfile lives in your repository next to the code.

```dockerfile
# Example: a Python FastAPI service
FROM python:3.11-slim                   # base image

WORKDIR /app                            # working directory inside the container

COPY requirements.txt .                 # copy only requirements first (layer cache)
RUN pip install --no-cache-dir -r requirements.txt  # install dependencies

COPY . .                               # copy the application code

EXPOSE 8000                            # document which port the app uses
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Step 2 — `docker build`: create the image**

```bash
docker build -t myapi:v1.0 .
```

Docker reads the `Dockerfile` top to bottom, executes each instruction, and creates a new layer for each one. The result is an image tagged `myapi:v1.0`.

**Step 3 — `docker run`: start the container**

```bash
docker run -d -p 8000:8000 --name api-server myapi:v1.0
```

Docker creates a container from the image and starts it. `-d` runs it in the background. `-p 8000:8000` forwards host port 8000 to port 8000 inside the container.

**Step 4 — The running container**

Your application is now running in an isolated environment. It has its own filesystem, network, and process space, but shares the host kernel.

**Step 5 — Debug**

```bash
docker logs api-server          # view stdout/stderr
docker logs -f api-server       # follow logs in real time
docker exec -it api-server sh   # open a shell inside the running container
```

**Step 6 — Fix the code → Rebuild**

You found a bug. Fix the code, then rebuild the image. Docker's layer cache means only the changed layers are rebuilt — usually fast.

```bash
# Only the COPY . . layer is rebuilt if the code changed
docker build -t myapi:v1.1 .
```

**Step 7 — Push to the registry**

```bash
docker tag myapi:v1.1 ghcr.io/myorg/myapi:v1.1
docker push ghcr.io/myorg/myapi:v1.1
```

The image is now available to any server, CI/CD pipeline, or colleague.

---

## 5. Essential Docker Commands

### Container lifecycle

#### `docker run`

```bash
docker run [OPTIONS] IMAGE [COMMAND]
```

Creates and starts a new container from an image.

| Flag | Meaning |
|--------|----------|
| `-d` | Background mode (detached) |
| `-p HOST:CONTAINER` | Publish a port |
| `--name NAME` | Give the container a name |
| `-e KEY=VALUE` | Set an environment variable |
| `-v VOLUME:PATH` | Mount a volume |
| `--rm` | Automatically remove the container after it stops |
| `-it` | Interactive + pseudo-TTY (for a shell) |

```bash
# Real examples:
docker run -d -p 5432:5432 -e POSTGRES_PASSWORD=secret --name pg postgres:15
docker run --rm -it python:3.11-slim bash
docker run -d -p 8000:8000 -v mydata:/app/data --name api myapi:v1.0
```

**Common mistake:** Forgetting `-d` and blocking the terminal, or forgetting `--rm` and piling up stopped containers.

---

#### `docker start` / `docker stop` / `docker restart`

```bash
docker stop api-server          # graceful stop (SIGTERM → SIGKILL after 10s)
docker start api-server         # start a stopped container
docker restart api-server       # stop + start
docker kill api-server          # immediate stop (SIGKILL, no grace period)
```

**Common mistake:** Using `docker kill` in production — always prefer `docker stop` for a graceful shutdown.

---

#### `docker ps`

```bash
docker ps               # running containers
docker ps -a            # all containers (including stopped ones)
docker ps -q            # container IDs only (useful for scripts)
```

```bash
# Stop all running containers:
docker stop $(docker ps -q)

# Remove all stopped containers:
docker rm $(docker ps -aq -f status=exited)
```

---

#### `docker rm`

```bash
docker rm api-server            # remove a stopped container
docker rm -f api-server         # force remove (even if running)
```

**Common mistake:** Confusing `docker stop` (stops gracefully) with `docker rm` (removes). You need to stop first and then remove, or use `-f`.

---

### Image management

#### `docker build`

```bash
docker build -t NAME:TAG CONTEXT_PATH
```

```bash
docker build -t myapp:1.0 .                       # from the current directory
docker build -t myapp:1.0 -f Dockerfile.prod .    # custom Dockerfile name
docker build --no-cache -t myapp:1.0 .            # ignore the layer cache (clean build)
docker build --target builder -t myapp:dev .      # build up to a specific stage (multi-stage)
```

**Common mistake:** Building from the wrong context (`.` means "send the current directory to the daemon"). Large directories slow down the build. Use `.dockerignore`.

---

#### `docker pull` / `docker push`

```bash
docker pull python:3.11-slim                      # download from a registry
docker push ghcr.io/myorg/myapp:v1.0              # upload to a registry
```

---

#### `docker images`

```bash
docker images                   # list all local images
docker images -q                # image IDs only
docker images myapp             # filter by name
```

---

#### `docker tag`

```bash
docker tag SOURCE_IMAGE TARGET_IMAGE
docker tag myapp:1.0 ghcr.io/myorg/myapp:1.0
docker tag myapp:1.0 myapp:latest
```

**Common mistake:** Thinking that `tag` creates a copy. It creates an **alias** — both names point to the same image layers.

---

### Debugging and inspection

#### `docker logs`

```bash
docker logs api-server          # print all logs
docker logs -f api-server       # follow (like tail -f)
docker logs --tail 50 api-server        # last 50 lines
docker logs --since 10m api-server      # logs from the last 10 minutes
```

**Common mistake:** Not using `-f` when debugging a running service — you need the stream.

---

#### `docker exec`

```bash
docker exec -it CONTAINER COMMAND
```

Runs a command **inside an already running** container without stopping it.

```bash
docker exec -it api-server bash         # open a bash shell
docker exec -it api-server sh           # open sh (for alpine images)
docker exec api-server env              # print environment variables
docker exec -it pg psql -U postgres     # connect to PostgreSQL inside the container
```

**Common mistake:** Using `docker exec` to "fix" things by manually editing files inside a running container. That change is **lost on restart**. Always fix it in the Dockerfile or the application code.

---

#### `docker inspect`

```bash
docker inspect CONTAINER|IMAGE
docker inspect api-server | python3 -m json.tool   # formatted output
docker inspect -f '{{.NetworkSettings.IPAddress}}' api-server  # extract a specific field
```

Returns full JSON metadata: network, mounts, environment variables, state, and so on.

---

#### `docker stats`

```bash
docker stats                    # resource usage for all containers
docker stats api-server         # a specific container
```

Shows CPU%, memory usage, network and disk I/O in real time. The `htop` equivalent for containers.

---

### System cleanup

```bash
# Remove stopped containers
docker container prune

# Remove dangling images (untagged, from old builds)
docker image prune

# Remove all unused images (not referenced by any container)
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Nuclear option: remove EVERYTHING unused (containers, images, networks, build cache)
docker system prune -a --volumes
```

**Common mistake:** Running `docker system prune` on a production server without checking what is "unused" — it may delete images referenced by stopped containers that you are about to restart.

**Check disk usage first:**

```bash
docker system df        # shows disk usage by images, containers, volumes
```

---

## 6. Docker Compose (multi-container systems)

### Why you need Compose

Real applications are never a single container. A typical web service has:

```
Your API (Python/FastAPI)
    + PostgreSQL database
    + Redis cache
    + Celery worker
    + Nginx reverse proxy
```

Managing this with separate `docker run` commands is painful:
- You have to remember the exact flags for each service
- You have to create networks and volumes manually
- Starting/stopping requires running 5+ commands in the right order
- Environment variables and secrets have to be passed manually every time

Docker Compose solves this with a **single `docker-compose.yml`** that declaratively defines all services, their configuration, and how they are connected.

```mermaid
flowchart TD
    Nginx["Nginx<br>Port 80/443"]
    WebApp["FastAPI<br>Port 8000"]
    Worker["Celery Worker<br>no port"]
    Database[("PostgreSQL<br>Port 5432")]
    Redis[("Redis<br>Port 6379")]

    Nginx -->|proxy_pass| WebApp
    WebApp -->|SQL queries| Database
    WebApp -->|task queue| Redis
    Worker -->|task processing| Redis
    Worker -->|SQL writes| Database

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class WebApp,Worker step;
    class Database,Redis success;
    class Nginx warning;
```

### A real `docker-compose.yml`

```yaml
services:
  api:
    build: ./services/api          # build from a local Dockerfile
    ports:
      - "8000:8000"                # publish to the host
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy  # wait until the DB is ready
      redis:
        condition: service_started
    volumes:
      - ./services/api:/app        # bind mount for development (live reload)
    networks:
      - backend

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - pgdata:/var/lib/postgresql/data   # named volume for persistence
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - backend

  redis:
    image: redis:7-alpine
    networks:
      - backend

  worker:
    build: ./services/worker
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis
    networks:
      - backend

volumes:
  pgdata:                          # Docker-managed persistent volume

networks:
  backend:                         # isolated virtual network for all services
    driver: bridge
```

### How services talk to each other

Inside a Compose network, **every service is reachable by its name as a hostname**.

```
From the 'api' container:
  Connect to PostgreSQL: postgresql://user:pass@db:5432/mydb
                                                      ^^
                                                      service name = hostname

  Connect to Redis: redis://redis:6379
                                ^^^^^
                                service name = hostname
```

Docker's built-in DNS resolver automatically maps names to IP addresses. You don't need to hard-code IP addresses.

### Essential Compose commands

```bash
docker compose up                   # start all services (foreground)
docker compose up -d                # start all services (background)
docker compose up --build           # rebuild images before starting
docker compose down                 # stop and remove containers + networks
docker compose down -v              # also remove volumes (CAREFUL: data loss)
docker compose logs -f api          # follow logs of a specific service
docker compose exec api bash        # shell in a running service
docker compose ps                   # list running services
docker compose restart api          # restart one service
docker compose build api            # rebuild the image of just one service
```

---

## 7. Volumes and Data Persistence

### Why containers are ephemeral

Every container has a **writable layer** on top of the image layers. When the container is removed, this layer is deleted. This is intentional — it makes containers disposable and reproducible.

```
Container lifecycle and data:

docker run postgres → [Container A] writes data to the writable layer
docker rm [Container A] → ALL DATA DELETED

docker run postgres → [Container B] starts EMPTY
```

This is a feature, not a bug. But it means you have to opt into persistence explicitly.

```mermaid
flowchart LR
    subgraph "Container (ephemeral)"
        App["Application"]
        WritableLayer["Writable layer<br>lost on rm"]
    end

    subgraph "Persistent storage"
        NamedVolume[("Named Volume<br>pgdata")]
        BindMount["Bind Mount<br>./code → /app"]
    end

    App -->|reads/writes| WritableLayer
    App -->|stores DB data| NamedVolume
    App -->|live code| BindMount

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class App step;
    class NamedVolume success;
    class WritableLayer error;
    class BindMount warning;
```

### Named Volumes vs Bind Mounts

**Named Volumes** — Docker manages the storage location:

```bash
# Create and use a named volume
docker volume create pgdata
docker run -v pgdata:/var/lib/postgresql/data postgres:15

# Inspect the volume
docker volume inspect pgdata

# The volume survives container removal:
docker rm -f my-postgres    # container removed
# the pgdata volume still exists with all its data
docker run -v pgdata:/var/lib/postgresql/data postgres:15   # the data is back!
```

**Bind Mounts** — you specify the exact path on the host:

```bash
# Mount the current directory into the container (development)
docker run -v $(pwd):/app -p 8000:8000 myapi:dev

# Mount a specific config file
docker run -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf nginx
```

**When to use which:**

| Scenario | Use |
|----------|----------------|
| DB files (PostgreSQL, MySQL) | Named volume |
| Development — live code reloading | Bind mount |
| Log files you need to access from the host | Bind mount |
| Production data that must survive restarts | Named volume |
| Secrets / credentials | Named volume or Docker secrets |
| CI/CD builds (one-off) | Nothing — the ephemeral writable layer |

### Volume commands

```bash
docker volume create mydata
docker volume ls
docker volume inspect mydata
docker volume rm mydata
docker volume prune              # remove all unused volumes
```

---

## 8. Networking

### How Docker networking works

When Docker starts, it creates a virtual network interface on the host (`docker0` on Linux). Containers connect to virtual networks that are bridged through this interface.

```mermaid
flowchart TD
    Internet(["Internet"])
    HostPort["Host port :80<br>(published)"]
    HostPort2["Host port :8000<br>(published)"]
    Bridge["bridge network<br>172.17.0.0/16"]
    Nginx["nginx<br>172.17.0.2"]
    API["api<br>172.17.0.3"]
    DB["postgres 172.17.0.4<br>(no published port)"]
    Redis["redis 172.17.0.5<br>(no published port)"]

    Internet --> HostPort --> Nginx
    Internet --> HostPort2 --> API
    Nginx -->|internally: api:8000| API
    API -->|internally: postgres:5432| DB
    API -->|internally: redis:6379| Redis

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Internet,Bridge,Nginx,API step;
    class DB,Redis success;
    class HostPort,HostPort2 warning;
```

### Publishing ports vs internal networking

**Published ports** (`-p HOST:CONTAINER`): Make a container port reachable from the host machine (and therefore from the network). Publish only what needs to be reachable from outside.

**Internal networking**: Containers on the same Docker network can communicate on any port by service name — **without publishing that port on the host**.

```bash
# WRONG: publishing the DB port to the outside (security risk)
docker run -p 5432:5432 postgres     # anyone can connect to your DB!

# RIGHT: the DB stays internal, the API is published
docker run -p 8000:8000 api          # the API is public
docker run postgres                  # the DB is reachable only inside the Docker network
```

### Network commands

```bash
docker network create mynet                     # create a custom bridge network
docker network ls                               # list networks
docker network inspect mynet                    # full details (IP ranges, connected containers)
docker network connect mynet api-container      # connect a running container to the network
docker network disconnect mynet api-container   # disconnect a container from the network
docker network rm mynet                         # remove the network
```

### DNS resolution inside Docker

Docker runs an **embedded DNS server** at `127.0.0.11` inside every container. It automatically resolves service names to container IP addresses.

```bash
# From the 'api' container:
ping db          # resolves to the postgres container IP
ping redis       # resolves to the redis container IP
curl http://nginx/health   # resolves to the nginx container
```

This means your application configuration should use **service names, never IP addresses**.

---

## 9. Common Mistakes

### Mistake 1: Using the `latest` tag

```dockerfile
# BAD
FROM python:latest
FROM node:latest
```

The `latest` tag means "whatever is the current latest at build time". Today that's Python 3.12. Next week it might be Python 3.13 with breaking changes. Your builds become non-reproducible.

```dockerfile
# GOOD: pin the exact version
FROM python:3.11.9-slim
FROM node:20.15.1-alpine
```

**Rule:** Always pin exact versions in `FROM` instructions. Treat them like the versions in `requirements.txt`.

---

### Mistake 2: Storing data inside containers

```bash
# BAD: writing to the container filesystem
docker exec api-server sh -c "echo 'config' > /app/config.json"
# This config is lost when the container restarts
```

```yaml
# GOOD: use volumes for any data that must persist
services:
  api:
    volumes:
      - ./config:/app/config     # bind mount the config from the host
      - appdata:/app/data        # named volume for generated data
```

Any file written directly into the container's writable layer is **ephemeral**. If the container crashes, is replaced by a new version, or is restarted by an orchestrator — that data is gone. Use volumes.

---

### Mistake 3: Not cleaning up resources

```bash
# After weeks of development, check disk usage:
docker system df
```

Common causes of disk bloat:
- **Stopped containers** piling up from every `docker run` without `--rm`
- **Dangling images** — intermediate layers from repeated builds (named `<none>:<none>`)
- **Old named volumes** from deleted projects
- **Build cache** from `docker build`

```bash
# Regular maintenance commands:
docker container prune          # remove stopped containers
docker image prune              # remove dangling images
docker system prune             # remove containers, networks, dangling images
docker system prune -a          # also remove unused images (not just dangling ones)
```

**Always use `--rm`** for one-off containers:

```bash
docker run --rm python:3.11 python -c "print('hello')"
# The container is removed automatically after it exits
```

---

### Mistake 4: Misusing `docker exec`

```bash
# BAD: "fixing" a running container via exec
docker exec api-server pip install missing-package
# The package is installed ONLY in the running container
# Next container restart: the package is gone
# Next deployment: the package is missing
# Other team members: the package is missing

# BAD: editing code directly inside the container
docker exec -it api-server vim /app/main.py
```

`docker exec` is a **diagnostic tool**, not a way to change the container (technically it can modify files, but those changes vanish on restart). It's for inspecting what is going on — checking logs, running `psql` to query the DB, debugging a network issue.

```bash
# GOOD uses of docker exec:
docker exec -it postgres psql -U user -d mydb    # connect to the DB to explore
docker exec api-server env                        # check environment variables
docker exec api-server python -c "import sys; print(sys.path)"  # debug imports
docker exec -it api-server curl localhost:8000/health  # check an internal endpoint
```

Any real change must go into your `Dockerfile` or application code, followed by `docker build` and a redeploy.

---

### Mistake 5: Wrong order of Dockerfile instructions

```dockerfile
# BAD: code changes invalidate the dependency layer
COPY . .                           # changes every time the code changes
RUN pip install -r requirements.txt  # reinstalls ALL dependencies even if they didn't change!
```

```dockerfile
# GOOD: dependencies are cached if requirements.txt hasn't changed
COPY requirements.txt .            # copy only requirements first
RUN pip install -r requirements.txt  # cached if requirements.txt hasn't changed
COPY . .                           # copy the code last (changes often)
```

Docker rebuilds from the first changed layer downward. Put **rarely changing instructions first** and **frequently changing ones last**.

---

## 10. Best Practices

### 1. Image layering: order for cache efficiency

```dockerfile
FROM python:3.11-slim

# Layer 1: System dependencies (rarely change)
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Layer 2: Python dependencies (change sometimes)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Layer 3: Application code (changes often)
COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Rule:** Stable → Semi-stable → Volatile. Dependencies before code.

---

### 2. Small images: use Alpine or Slim variants

| Base image | Size | Usage |
|--------------|--------|--------------|
| `python:3.11` | ~1 GB | Never in production |
| `python:3.11-slim` | ~130 MB | The standard choice for production |
| `python:3.11-alpine` | ~50 MB | Smallest, but may lack libraries |
| `gcr.io/distroless/python3` | ~30 MB | Maximum security (no shell) |

```dockerfile
# Use slim or alpine where possible:
FROM python:3.11-slim
FROM node:20-alpine
FROM nginx:1.25-alpine
```

Also: always clean package manager caches in the same layer:

```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*   # MUST be in the same RUN to reduce the layer size
```

---

### 3. Multi-stage builds for production

Build tools, compilers, and test dependencies should not be in your production image.

```dockerfile
# Stage 1: Builder (has compilers, dev tools)
FROM python:3.11-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# Stage 2: Production (minimal, no build tools)
FROM python:3.11-slim AS production
WORKDIR /app
COPY --from=builder /install /usr/local    # copy only the installed packages
COPY src/ .
CMD ["python", "main.py"]
```

The production image contains only what is needed to run — not to build. A smaller attack surface, a smaller size.

---

### 4. Reproducibility: `.dockerignore`

```dockerignore
# .dockerignore — prevents unnecessary files from being sent to the Docker daemon
.git
.gitignore
__pycache__
*.pyc
*.pyo
.env
.env.*
.venv
venv/
node_modules/
*.log
dist/
build/
.pytest_cache/
.mypy_cache/
```

Without `.dockerignore`, `COPY . .` sends your entire directory (including `.git`, `venv`, `node_modules`) to the Docker daemon. This slows builds down significantly and increases the image size.

---

### 5. Dev vs Prod: separate Compose files

```
docker-compose.yml          ← base configuration (shared services)
docker-compose.dev.yml      ← dev overrides (bind mounts, debug ports)
docker-compose.prod.yml     ← prod overrides (resource limits, restart policies)
```

```yaml
# docker-compose.yml (base)
services:
  api:
    image: myapi:${TAG:-latest}
    environment:
      - DATABASE_URL=${DATABASE_URL}

# docker-compose.dev.yml (dev override)
services:
  api:
    build: .                           # local build for dev
    volumes:
      - .:/app                         # live reload
    environment:
      - DEBUG=true
    command: uvicorn main:app --reload

# docker-compose.prod.yml (prod override)
services:
  api:
    restart: always                    # auto-restart on failure
    deploy:
      resources:
        limits:
          memory: 512M
```

```bash
# Development:
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Production:
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

### 6. Security basics

**Never run as root:**

```dockerfile
# Create an unprivileged user
RUN addgroup --system app && adduser --system --group app
USER app                    # all following instructions run as 'app'
```

**Never store secrets in the Dockerfile or the image:**

```dockerfile
# BAD: the secret is baked into an image layer (visible in history)
ENV DATABASE_PASSWORD=supersecret

# GOOD: pass it at runtime
# docker run -e DATABASE_PASSWORD=$SECRET_FROM_VAULT myapi
```

**Use a read-only filesystem where possible:**

```bash
docker run --read-only --tmpfs /tmp myapi    # read-only filesystem except /tmp (in memory)
```

**Scan images for vulnerabilities:**

```bash
docker scout cves myapi:v1.0    # Docker's built-in scanner
trivy image myapi:v1.0          # Trivy (a popular open-source scanner)
```

---

### Quick reference

```
Build:     docker build -t name:tag .
Run:       docker run -d -p 8000:8000 --name app name:tag
Logs:      docker logs -f app
Shell:     docker exec -it app bash
Stop:      docker stop app
Remove:    docker rm app
Images:    docker images
Cleanup:   docker system prune -a

Compose:
  Start:   docker compose up -d --build
  Stop:    docker compose down
  Logs:    docker compose logs -f service
  Shell:   docker compose exec service bash
```

---

## 11. Official Images for the Python Advanced Course

All the images listed are official and available on **[Docker Hub](https://hub.docker.com/)**.

### 11.1 Python

**Image:** [`python`](https://hub.docker.com/_/python) — the official Python interpreter image.

```bash
docker pull python:3.11-slim
```

| Tag | Size | When to use |
|-----|--------|----------------------|
| `python:3.11` | ~1 GB | Never in production |
| `python:3.11-slim` | ~130 MB | Standard: production services |
| `python:3.11-alpine` | ~50 MB | Minimal size (less compatibility) |

```bash
# Start a Python REPL in a container
docker run --rm -it python:3.11-slim python

# Run a script from the current directory
docker run --rm -v $(pwd):/app -w /app python:3.11-slim python my_script.py
```

---

### 11.2 PostgreSQL

**Image:** [`postgres`](https://hub.docker.com/_/postgres) — the official image of the PostgreSQL relational DBMS.

```bash
docker pull postgres:16-alpine
```

| Environment variable | Required | Default value |
|-------------------|-------------|---------------------------|
| `POSTGRES_PASSWORD` | Yes | — |
| `POSTGRES_USER` | No | `postgres` |
| `POSTGRES_DB` | No | `= POSTGRES_USER` |

```bash
# Start PostgreSQL
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_USER=user \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16-alpine

# Connect via psql
docker exec -it my-postgres psql -U user -d mydb
```

---

### 11.3 MongoDB

**Image:** [`mongo`](https://hub.docker.com/_/mongo) — the official image of the MongoDB document-oriented NoSQL database.

```bash
docker pull mongo:7
```

| Environment variable | Description |
|-------------------|------|
| `MONGO_INITDB_ROOT_USERNAME` | Admin user name |
| `MONGO_INITDB_ROOT_PASSWORD` | Admin password |
| `MONGO_INITDB_DATABASE` | Initial database |

```bash
# Start MongoDB
docker run -d \
  --name my-mongo \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  -p 27017:27017 \
  -v mongodata:/data/db \
  mongo:7

# Connect via mongosh
docker exec -it my-mongo mongosh -u admin -p secret
```

```python
# Python connection (pymongo)
from pymongo import MongoClient
client = MongoClient("mongodb://admin:secret@localhost:27017/")
db = client["mydb"]
```

---

### 11.4 Redis

**Image:** [`redis`](https://hub.docker.com/_/redis) — the official image of the in-memory data store. Used as a cache, a message broker (Celery), and for pub/sub.

```bash
docker pull redis:7-alpine
```

```bash
# Start Redis
docker run -d \
  --name my-redis \
  -p 6379:6379 \
  redis:7-alpine

# Connect via redis-cli
docker exec -it my-redis redis-cli

# Basic redis-cli commands:
# SET key value
# GET key
# DEL key
# KEYS *
```

```python
# Python connection (redis-py)
import redis
r = redis.Redis(host="localhost", port=6379, decode_responses=True)
r.set("name", "Docker")
print(r.get("name"))  # Docker
```

---

### 11.5 Neo4j

**Image:** [`neo4j`](https://hub.docker.com/_/neo4j) — the official image of the Neo4j graph DBMS. It stores data as nodes and relationships.

```bash
docker pull neo4j:5
```

| Port | Purpose |
|------|-------------|
| `7474` | Neo4j Browser (web interface) |
| `7687` | Bolt protocol (for application connections) |

```bash
# Start Neo4j
docker run -d \
  --name my-neo4j \
  -p 7474:7474 \
  -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/password \
  -v neo4jdata:/data \
  neo4j:5

# Open in the browser:
# http://localhost:7474
# Login: neo4j / Password: password
```

```python
# Python connection (neo4j driver)
from neo4j import GraphDatabase
driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "password"))

with driver.session() as session:
    session.run("CREATE (n:Person {name: 'Alice'})")
    result = session.run("MATCH (n:Person) RETURN n.name")
    for record in result:
        print(record["n.name"])
```

---

### 11.6 Ubuntu

**Image:** [`ubuntu`](https://hub.docker.com/_/ubuntu) — the official Ubuntu OS image. Used as a base image or for interactive sessions.

```bash
docker pull ubuntu:24.04
```

```bash
# Start an interactive Ubuntu session
docker run --rm -it ubuntu:24.04 bash

# Install packages and test
docker run --rm -it ubuntu:24.04 bash -c "
  apt-get update -qq && \
  apt-get install -y python3 python3-pip && \
  python3 --version
"
```

---

### Course images summary table

| Image | Version | Port | Purpose |
|-------|--------|------|-------------|
| `python` | `3.11-slim` | — | Running Python applications |
| `postgres` | `16-alpine` | 5432 | Relational DB |
| `mongo` | `7` | 27017 | Document NoSQL DB |
| `redis` | `7-alpine` | 6379 | Cache / message broker |
| `neo4j` | `5` | 7474, 7687 | Graph DB |
| `ubuntu` | `24.04` | — | Base OS / learning environment |

---

*Docker Guide · Module 3 · Python Advanced · Viktor Nikoriak*
