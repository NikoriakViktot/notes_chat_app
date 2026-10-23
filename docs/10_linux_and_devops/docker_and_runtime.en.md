# Docker and Runtime

> Docker describes the runtime, but the runtime has to match the actual structure of the repository.

## What the student will learn

- the basic mental model of the topic;
- how the topic works in Django;
- where to see it in the final project;
- how to check that the understanding is not just theoretical.

## Prerequisites

- Be able to open the repository.
- Understand that all paths in the documentation are relative to the `notes_chat_app` root.

## Current status

`docker-compose.yml` describes the services db (PostgreSQL), redis, web (Uvicorn, port 8001), nginx, celery-worker, celery-beat, plus selenium/selenium-tests (profile `test`) and ngrok (profile `tunnel`). The `Dockerfile` builds one image from the project root (`context: .`, `COPY . .`), and that image is used by web, celery-worker, celery-beat and selenium-tests.

## Environment

`DATABASE_URL` is required: Django connects to PostgreSQL, and without this variable `settings.py` raises an Exception. `REDIS_URL` switches Channels to Redis.

## Where to find it in the final project

| File | What to look at |
| --- | --- |
| `Dockerfile` | image build |
| `docker-compose.yml` | service graph |
| `entrypoint.sh` | runtime command |

## Practical exercise

Make a plan for fixing Docker without changing the application code.

## Review questions

- What is the input to this process?
- What result is expected?
- Where does an error most often occur?
- Which command or test helps verify the change?

## Next

Next: [Deployment](../11_deployment/README.md).
