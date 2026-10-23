# Learning Path

This path takes you from the basic web model to the final Django project. Read the sections in order if you are a beginner. If you only need the project, go straight to `12_final_project`.

## 1. Internet and HTTP

Start with [web foundations](01_web_foundations/README.md). The goal is to understand that the browser does not call Python directly. It sends an HTTP request to the server.

Check: explain the difference between a URL, DNS, an IP address, a TCP port, and an HTTP path.

## 2. Django architecture

Move on to [Django core](02_django_core/README.md). The goal is to see Django as a pipeline: middleware -> URL dispatcher -> view -> template/response.

Check: find the `/notes/` route in `notes_app/urls.py`.

## 3. Database and ORM

Read [database and ORM](03_database_and_orm/README.md). The goal is to understand why `models.py` is the domain schema and migrations are the history of database changes.

Check: explain the relationships between `Note`, `Notebook`, `Tag`, `Reminder`.

## 4. Forms and templates

Read [forms](04_forms_and_validation/README.md) and [frontend/templates](05_frontend_and_templates/README.md). The goal is to understand the trust boundary: browser input cannot be trusted, and the server must validate it.

Check: find `NoteForm.__init__` and explain why it accepts `user`.

## 5. Application architecture

Read [services/selectors](06_application_architecture/README.md). The goal is to separate HTTP, reading data, and changing data.

Check: name one selector and one service from the current project.

## 6. Auth and security

Read [auth and security](07_auth_and_security/README.md). The goal is to distinguish authentication from authorization and to prevent IDOR.

Check: explain why `@login_required` is not enough for `note_detail`.

## 7. Testing and CI

Read [testing](08_testing_and_quality/README.md). The goal is to be able to verify a model, service, form, view, consumer, and E2E flow.

Check: run one test module after installing the dependencies.

## 8. Async and WebSocket

Read [async and realtime](09_async_and_realtime/README.md). The goal is to understand why the chat uses ASGI and a Consumer.

Check: draw the flow from `group_chat.js` to `GroupChatConsumer`.

## 9. Linux, Docker, deployment

Read [Linux and DevOps](10_linux_and_devops/README.md) and [deployment](11_deployment/README.md). The goal is to tell apart GitHub, CI, the server, and the production runtime.

Check: explain why `DEBUG=True` must not be left on the server.

## 10. Final project

Read [final project](12_final_project/README.md). The goal is to bring all the concepts together in one real codebase.

Check: open the [feature map](12_final_project/feature_map.md) and verify every feature in the code.
