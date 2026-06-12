# Project Overview

`notes_chat_app` - навчальний Django-проєкт, який поєднує CRUD, authentication, sharing, tests і realtime chat.

## Проблема

Студентам часто важко побачити, як окремі теми Django складаються в один застосунок. Цей проєкт показує всі шари в одному codebase.

## Основні ролі

- Anonymous user: може відкрити index, register і login.
- Authenticated user: керує своїми notes, todo lists, shopping lists.
- Group member: бачить group-owned notes/shopping lists і group chat.

## Не реалізовано як поточна feature

- DRF serializers/API.
- Celery tasks.
- Production-ready Docker deployment.
- Kubernetes.
