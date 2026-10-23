# 11. Deploying Django on Linux

## Why you need this

You've written a Django project. It runs on your laptop. Now you need real users to be able to see it — over the internet, 24/7. That is what **deployment** is.

This file is a step-by-step guide: from `git clone` to a working website.

---

## What deployment is

Deployment is the process of moving code from your local development environment to a server where it will be available to users.

```mermaid
flowchart TD
    Local["Local Django project<br>(laptop, DEBUG=True)"] --> Git["Push to Git<br>(GitHub/GitLab)"]
    Git --> Server["Pull on Linux server<br>(Ubuntu)"]
    Server --> Venv["Create a virtualenv<br>Install dependencies"]
    Venv --> Env["Configure .env<br>(DEBUG=False, DB credentials)"]
    Env --> Migrate["python manage.py migrate"]
    Migrate --> Static["python manage.py collectstatic"]
    Static --> AppServer["Start Gunicorn/Uvicorn"]
    AppServer --> Nginx["Nginx accepts requests<br>and proxies them to the app server"]
    Nginx --> Users["Users"]

    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;
    class Local,Git,Server,Venv,Migrate,Static,AppServer,Nginx step;
    class Users success;
    class Env warning;
```

---

## Preparing the server

```bash
# Connect to the server
ssh ubuntu@your_server_ip

# Update the system
sudo apt update && sudo apt upgrade -y

# Install the required packages
sudo apt install python3 python3-venv python3-pip git nginx -y

# Install PostgreSQL (if you use it)
sudo apt install postgresql postgresql-contrib -y
```

---

## Setting up PostgreSQL on the server

```bash
sudo -u postgres psql

-- Inside psql:
CREATE DATABASE myapp_db;
CREATE USER myapp_user WITH PASSWORD 'strong_password_here';
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myapp_user;
\q
```

---

## Cloning and configuring the project

```bash
# Go to the directory for web projects
cd /var/www/

# Clone the repository
sudo git clone https://github.com/you/myproject.git myapp
sudo chown -R $USER:$USER /var/www/myapp
cd /var/www/myapp

# Create a virtualenv
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install Gunicorn (if it is not in requirements.txt)
pip install gunicorn
```

---

## The .env file on the server

```bash
nano /var/www/myapp/.env
```

```env
DEBUG=False
SECRET_KEY=your-production-secret-key-very-long-and-random
DATABASE_URL=postgres://myapp_user:strong_password_here@localhost:5432/myapp_db
ALLOWED_HOSTS=your-domain.com,www.your-domain.com,your_server_ip
STATIC_ROOT=/var/www/myapp/staticfiles
MEDIA_ROOT=/var/www/myapp/media
```

```bash
chmod 600 /var/www/myapp/.env
```

> `DEBUG=False` in production is mandatory. Otherwise Django shows stack traces with database data.

---

## Migrations and static files

```bash
source /var/www/myapp/.venv/bin/activate
cd /var/www/myapp

python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser   # if you need an admin
```

`collectstatic` gathers all static files (CSS, JS, images) into a single `STATIC_ROOT` directory. Nginx serves them directly from there, without touching Django.

---

## Checking that Django starts

```bash
# Test — start it and see whether there are errors
python manage.py check --deploy

# Start Gunicorn manually (to check)
gunicorn myapp.wsgi:application --bind 0.0.0.0:8000
```

If you open `http://your_server_ip:8000` in a browser, the site should open (without CSS, because Nginx is not configured yet).

Stop Gunicorn: `Ctrl+C`

---

## A systemd service for Django

Create the service file:

```bash
sudo nano /etc/systemd/system/myapp.service
```

```ini
[Unit]
Description=Django Application - myapp
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/myapp
EnvironmentFile=/var/www/myapp/.env
ExecStart=/var/www/myapp/.venv/bin/gunicorn \
    myapp.wsgi:application \
    --workers 3 \
    --bind unix:/run/myapp.sock \
    --log-file /var/log/myapp/gunicorn.log \
    --access-logfile /var/log/myapp/access.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
# Create a directory for logs
sudo mkdir -p /var/log/myapp
sudo chown www-data:www-data /var/log/myapp

# Give www-data ownership of the project
sudo chown -R www-data:www-data /var/www/myapp

# Start it and enable autostart
sudo systemctl daemon-reload
sudo systemctl start myapp
sudo systemctl enable myapp
sudo systemctl status myapp
```

> `--bind unix:/run/myapp.sock` — Gunicorn listens on a Unix socket instead of a TCP port. This is faster and safer for local communication with Nginx.

---

## Nginx configuration

```bash
sudo nano /etc/nginx/sites-available/myapp
```

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;

    location /static/ {
        alias /var/www/myapp/staticfiles/;
    }

    location /media/ {
        alias /var/www/myapp/media/;
    }

    location / {
        proxy_pass http://unix:/run/myapp.sock;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
# Activate the config
sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t              # check the syntax
sudo systemctl restart nginx
```

---

## Why you must not use runserver in production

| `runserver` | Gunicorn |
|---|---|
| Single-threaded | Several workers (parallel requests) |
| Designed for debugging | Optimized for production |
| Does not support Unix sockets | Supports them |
| Slow | Fast |
| No SSL | Nginx adds SSL |

---

## Common deployment mistakes

**Mistake 1:** `DisallowedHost at /`
> Add the domain and IP to `ALLOWED_HOSTS` in `.env`

**Mistake 2:** CSS/JS do not load
> Run `python manage.py collectstatic`. Check the `STATIC_ROOT` path and the Nginx config.

**Mistake 3:** `502 Bad Gateway`
> Gunicorn is not running or cannot connect to the socket. `systemctl status myapp`

**Mistake 4:** Database errors
> Check `DATABASE_URL` in `.env`. Does `www-data` have access to PostgreSQL?

---

## Practical exercise

### Task 1
Prepare a `requirements.txt` for production: add `gunicorn`, `psycopg2-binary`, `python-decouple`.

### Task 2
Start Gunicorn manually and check that the site opens:
```bash
gunicorn myapp.wsgi:application --bind 0.0.0.0:8000 --log-level debug
```

### Task 3
Write a systemd unit file for your project and explain every line.

---

## Self-check

- [ ] I can explain all the steps of deploying Django, from git clone to a running site
- [ ] I know that `DEBUG=False` is mandatory in production
- [ ] I understand why `collectstatic` is needed and what `STATIC_ROOT` is
- [ ] I can write a systemd unit file for Django
- [ ] I know why `runserver` must not be used in production

---

## Short summary

Deploying Django means: clone the code, configure `.env`, create a virtualenv, install dependencies, run migrations and collectstatic, start Gunicorn via systemd, and configure Nginx. Next, we will look at Nginx and Gunicorn in more detail.
