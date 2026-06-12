# Learning Path

Цей маршрут веде від базової web-моделі до фінального Django-проєкту. Читайте розділи послідовно, якщо ви початківець. Якщо вам потрібен лише проєкт, переходьте до `12_final_project`.

## 1. Internet і HTTP

Почніть з [web foundations](01_web_foundations/README.md). Мета - зрозуміти, що browser не викликає Python напряму. Він надсилає HTTP request до server.

Контроль: поясніть різницю між URL, DNS, IP, TCP port і HTTP path.

## 2. Django architecture

Перейдіть до [Django core](02_django_core/README.md). Мета - побачити Django як конвеєр: middleware -> URL dispatcher -> view -> template/response.

Контроль: знайдіть route `/notes/` у `notes_app/urls.py`.

## 3. Database і ORM

Читайте [database and ORM](03_database_and_orm/README.md). Мета - зрозуміти, чому `models.py` є схемою домену, а migrations є історією зміни БД.

Контроль: поясніть зв'язки `Note`, `Notebook`, `Tag`, `Reminder`.

## 4. Forms і templates

Читайте [forms](04_forms_and_validation/README.md) і [frontend/templates](05_frontend_and_templates/README.md). Мета - зрозуміти trust boundary: browser input не можна довіряти, server має validate.

Контроль: знайдіть `NoteForm.__init__` і поясніть, чому він приймає `user`.

## 5. Application architecture

Читайте [services/selectors](06_application_architecture/README.md). Мета - відділити HTTP, читання даних і зміну даних.

Контроль: назвіть один selector і один service з поточного проєкту.

## 6. Auth і security

Читайте [auth and security](07_auth_and_security/README.md). Мета - відрізняти authentication від authorization і не допустити IDOR.

Контроль: поясніть, чому `@login_required` не достатній для `note_detail`.

## 7. Testing і CI

Читайте [testing](08_testing_and_quality/README.md). Мета - вміти перевірити model, service, form, view, consumer і E2E flow.

Контроль: запустіть один test module після встановлення dependencies.

## 8. Async і WebSocket

Читайте [async and realtime](09_async_and_realtime/README.md). Мета - зрозуміти, чому chat використовує ASGI і Consumer.

Контроль: намалюйте flow від `group_chat.js` до `GroupChatConsumer`.

## 9. Linux, Docker, deployment

Читайте [Linux and DevOps](10_linux_and_devops/README.md) і [deployment](11_deployment/README.md). Мета - відрізнити GitHub, CI, server і production runtime.

Контроль: поясніть, чому `DEBUG=True` не можна залишати на server.

## 10. Final project

Читайте [final project](12_final_project/README.md). Мета - зібрати всі концепції в одному реальному codebase.

Контроль: відкрийте [feature map](12_final_project/feature_map.md) і перевірте кожну feature у коді.
