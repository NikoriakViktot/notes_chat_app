#!/bin/sh
set -e

python manage.py migrate --noinput
python manage.py collectstatic --noinput

# SEED_DEMO_DATA=1 → заповнити БД демо-даними (тільки при DEBUG=True)
if [ "${SEED_DEMO_DATA}" = "1" ]; then
    python manage.py seed_demo_data --force
fi

exec python -m uvicorn notes_project.asgi:application \
    --host 0.0.0.0 --port 8001 --reload
