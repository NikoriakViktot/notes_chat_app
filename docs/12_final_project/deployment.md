# Final Project Deployment

## Current status

Deployment is not yet production-ready.

Ready pieces:

- `.env.example`
- PostgreSQL switching through `DATABASE_URL`
- Redis switching through `REDIS_URL`
- ASGI app
- static settings

Needs work:

- environment-based `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`;
- Docker build path fix;
- production server command without `--reload`;
- HTTPS and secure cookies;
- logging and monitoring;
- backup/rollback plan.
