# Teaching Guide

This document helps a teacher turn the repository into a course.

## Short route

1. Local setup and repository structure.
2. Django URL -> view -> template.
3. Models, migrations, and the ORM.
4. Forms, validation, PRG.
5. Auth and object-level permissions.
6. Tests.
7. The final project.

## Standard route

Add to the short route:

- services/selectors;
- query optimization;
- template inheritance and Bootstrap;
- Selenium;
- CI;
- WebSocket chat.

## Full route

Add:

- web foundations;
- Linux basics;
- a Docker mental model;
- a deployment checklist;
- production security.

## What to show in live coding

- Add a simple route and view.
- Add a model field and a migration.
- Add form validation.
- Move a query into a selector.
- Write a service test.
- Show an IDOR bug and the test that catches it.
- Show a WebSocket connection in the browser DevTools.

## Homework

- Minimal: change a template and add a test.
- Core: add a feature through a model, form, service, view, template.
- Advanced: restore the async HTTP demo with the full set of files or fix the Docker setup.

## Difficult topics for beginners

- QuerySet laziness.
- The difference between authentication and authorization.
- ManyToMany and the through table.
- Transactions.
- ASGI and the WebSocket lifecycle.
- Production settings.

## Grading criteria for the final project

- `python manage.py check` passes.
- Tests cover model/service/form/view.
- Object permissions are verified.
- No secrets in Git.
- The README and docs match the actual code.
- Deployment notes honestly separate what is ready from what is planned.

## What can be skipped in a shortened course

- Kubernetes overview.
- Deep indexing.
- Advanced transactions.
- SIEM.
- Serializers, because they are not implemented in the final project.
- Celery (background reminders), if time is short: it is implemented (`notes_app/tasks.py`, the `celery-worker` and `celery-beat` services), but the rest of the application works without it.
