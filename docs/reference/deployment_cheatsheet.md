# Deployment Cheatsheet

Production checklist:

- `DEBUG=False`
- real `ALLOWED_HOSTS`
- secret settings from environment
- PostgreSQL
- Redis for Channels
- `collectstatic`
- HTTPS
- logging and backups
