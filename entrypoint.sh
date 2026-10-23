#!/bin/sh
set -eu

log() {
    printf '[entrypoint] %s\n' "$1"
}

if [ "${RUN_MIGRATIONS:-1}" = "1" ]; then
    log "Applying database migrations..."
    python manage.py migrate --noinput
fi

if [ "${RUN_COLLECTSTATIC:-1}" = "1" ]; then
    log "Collecting static files..."
    python manage.py collectstatic --noinput
fi

if [ "${CREATE_SUPERUSER:-0}" = "1" ]; then
    log "Creating/updating Django superuser ${DJANGO_SUPERUSER_USERNAME:-admin}..."
    python manage.py shell -c "
import os
from django.contrib.auth import get_user_model

User = get_user_model()
username = os.environ.get('DJANGO_SUPERUSER_USERNAME', 'admin')
email = os.environ.get('DJANGO_SUPERUSER_EMAIL', 'admin@example.com')
password = os.environ.get('DJANGO_SUPERUSER_PASSWORD', 'admin12345')

user, _ = User.objects.get_or_create(username=username)
user.email = email
user.is_staff = True
user.is_superuser = True
user.is_active = True
user.set_password(password)
user.save()
"
fi

if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
    seed_args="--force"
    if [ "${SEED_DEMO_RESET:-0}" = "1" ]; then
        seed_args="--force --reset"
    fi
    log "Seeding demo data with args: ${seed_args}"
    python manage.py seed_demo_data ${seed_args}
fi

port="${PORT:-8001}"
set -- --host 0.0.0.0 --port "${port}" --proxy-headers --forwarded-allow-ips '*'

if [ "${UVICORN_RELOAD:-1}" = "1" ]; then
    set -- "$@" --reload
fi

log "Starting ASGI web server on port ${port}..."
exec python -m uvicorn notes_project.asgi:application "$@"
