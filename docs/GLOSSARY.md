# Glossary

Терміни курсу Django і Notes Chat App. Відсортовано за абеткою (англійська літера).

---

## A

| Термін | Пояснення |
|--------|-----------|
| **annotate** | ORM метод, що додає обчислене поле до кожного об'єкту QuerySet (наприклад, `Count`, `Sum`) без N+1 запитів |
| **ASGI** | Async Server Gateway Interface — async-capable Python web interface, потрібний для WebSocket і async runtime. Замінює WSGI для real-time застосунків |
| **AsyncWebsocketConsumer** | Базовий клас Django Channels для async WebSocket consumer (аналог `View` для HTTP) |
| **Authentication** | Перевірка, хто є користувач (login / session) |
| **AuthMiddlewareStack** | Django Channels middleware, що читає session cookie з WS handshake і наповнює `scope["user"]` |
| **Authorization** | Перевірка, що користувачу дозволено робити (object-level permission) |
| **auto_now_add** | Параметр DateTimeField: записує поточний час лише при створенні об'єкту |

## C

| Термін | Пояснення |
|--------|-----------|
| **CASCADE** | `on_delete` поведінка: при видаленні батьківського об'єкту видаляються всі пов'язані дочірні об'єкти |
| **channel group** | Логічна група Channels-каналів; `group_send` надсилає подію всім учасникам групи |
| **channel layer** | Pub/sub шар Django Channels — передає повідомлення між Consumer instances (InMemory або Redis) |
| **CheckConstraint** | Обмеження на рівні БД: перевіряє Q-вираз при INSERT/UPDATE. Наприклад, `Q(priority__gte=1)` |
| **Consumer** | Channels-клас, що обробляє WebSocket lifecycle (connect / receive / disconnect) |
| **CSRF** | Cross-Site Request Forgery — атака, де чужий сайт змушує браузер надіслати небажаний POST від імені залогіненого user |
| **Crispy Forms** | Django-пакет для Bootstrap-стилізованого рендерингу форм через `CrispyFormHelper` |

## D

| Термін | Пояснення |
|--------|-----------|
| **database_sync_to_async** | Channels decorator/wrapper: запускає синхронну ORM-функцію у Django thread pool з async context |
| **DEBUG** | Django setting: `True` — детальні error pages; `False` — 500 без traceback. Ніколи `True` у production |
| **Deployment** | Запуск застосунку на сервері для реальних користувачів |
| **Django app** | Модуль Django з models, views, forms, templates; реєструється в `INSTALLED_APPS` |
| **Django project** | Package з `settings.py`, root urls, `wsgi.py`/`asgi.py`; оточує один або декілька apps |
| **docker compose** | Інструмент для оркестрації кількох Docker-контейнерів через `docker-compose.yml` |

## E

| Термін | Пояснення |
|--------|-----------|
| **entrypoint.sh** | Shell-скрипт, що виконується при старті Docker контейнера: migrate → collectstatic → seed → exec server |
| **event loop** | Asyncio механізм для виконання coroutines; один на процес; не можна блокувати синхронними викликами |

## F

| Термін | Пояснення |
|--------|-----------|
| **ForeignKey** | Поле моделі: зовнішній ключ до іншої таблиці. Параметр `on_delete` визначає поведінку при видаленні батьківського запису |
| **Form** | Django клас для validation і rendering input fields. `ModelForm` — форма на основі моделі |

## G

| Термін | Пояснення |
|--------|-----------|
| **Group** | Django built-in: `django.contrib.auth.models.Group`; використовується для групового ділення нотаток і чату |

## H

| Термін | Пояснення |
|--------|-----------|
| **health check** | Docker: умова готовності контейнера (наприклад, `pg_isready` для PostgreSQL); інші сервіси чекають на неї перед стартом |

## I

| Термін | Пояснення |
|--------|-----------|
| **IDOR** | Insecure Direct Object Reference — доступ до чужого об'єкту через зміну `pk` у URL без перевірки ownership |
| **InMemoryChannelLayer** | Channel layer без Redis; підходить для розробки з одним процесом; не передає повідомлення між різними Uvicorn workers |
| **index (DB)** | Структура даних у БД для прискорення SELECT по певних полях. У Django — `models.Index` в `Meta.indexes` |

## L

| Термін | Пояснення |
|--------|-----------|
| **lazy evaluation** | QuerySet не виконує SQL до моменту ітерації або явного перетворення (`list()`, `bool()`, `len()`) |
| **login_required** | Django decorator: перенаправляє анонімного user на `/accounts/login/` |

## M

| Термін | Пояснення |
|--------|-----------|
| **ManyToManyField** | Поле моделі: many-to-many відношення через проміжну junction таблицю |
| **Middleware** | Проміжний шар між request і view (або view і response): обробляє кожен запит/відповідь |
| **Migration** | Версійний опис зміни database schema; генерується `makemigrations`, застосовується `migrate` |
| **Model** | Python-клас, що описує таблицю БД і доменну сутність |

## N

| Термін | Пояснення |
|--------|-----------|
| **N+1 problem** | Антипатерн: 1 запит на список + N запитів для кожного елементу. Вирішується `select_related` або `prefetch_related` |
| **Nginx** | Reverse proxy і web server: приймає HTTP/WebSocket запити і проксіює до ASGI server |

## O

| Термін | Пояснення |
|--------|-----------|
| **on_delete** | Параметр FK: поведінка при видаленні батьківського запису. `CASCADE` — видалити дочірні; `SET_NULL` — встановити null |
| **ORM** | Object Relational Mapper: шар роботи з БД через Python об'єкти без SQL |

## P

| Термін | Пояснення |
|--------|-----------|
| **prefetch_related** | ORM оптимізація: виконує окремий SELECT для пов'язаних об'єктів (M2M або зворотній FK) і кешує результат |
| **primary key (pk)** | Унікальний ідентифікатор запису в таблиці. У Django — автоматичне `id = AutoField` якщо не вказано інше |
| **ProtocolTypeRouter** | ASGI router: розподіляє трафік за типом протоколу (`http` → Django, `websocket` → Channels) |

## Q

| Термін | Пояснення |
|--------|-----------|
| **Q object** | Django ORM об'єкт для складних WHERE умов з операторами `|` (OR), `&` (AND), `~` (NOT) |
| **QuerySet** | Лінивий об'єкт, що описує database query; матеріалізується при ітерації або `list()` |

## R

| Термін | Пояснення |
|--------|-----------|
| **Redis** | In-memory key-value store: використовується як channel layer для передачі WS повідомлень між consumer instances |
| **related_name** | Параметр FK/M2M: ім'я зворотнього зв'язку. `related_name='notes'` → `notebook.notes.all()` |
| **reverse proxy** | Сервер (Nginx), що приймає зовнішні запити і передає їх внутрішньому ASGI серверу |

## S

| Термін | Пояснення |
|--------|-----------|
| **scope** | Channels: dict з метаданими з'єднання (аналог `request` у HTTP). Містить `user`, `url_route`, `headers` |
| **select_related** | ORM оптимізація: виконує SQL JOIN для FK і OneToOne полів; завантажує пов'язані об'єкти одним запитом |
| **Selector** | Функція у `selectors.py`, відповідальна лише за SELECT/read queries з правилами доступу |
| **Service** | Функція у `services.py`, відповідальна за business операцію і мутацію даних |
| **Session** | Server-side стан, пов'язаний з браузером через cookie `sessionid`; зберігає автентифікованого user |
| **SET_NULL** | `on_delete` поведінка: FK поле встановлюється в `NULL` замість CASCADE при видаленні батьківського запису |
| **socket_timeout** | Параметр RedisChannelLayer CONFIG: `None` = без таймауту. Без нього Redis закриє idle з'єднання → `TimeoutError` |
| **StaticLiveServerTestCase** | Django клас для Selenium тестів: запускає реальний сервер і роздає статичні файли |

## T

| Термін | Пояснення |
|--------|-----------|
| **Template** | HTML-файл з Django template language `{{ }}` і `{% %}` тегами |
| **TestCase** | Django клас для тестів: загортає кожен тест у транзакцію (rollback після кожного тесту) |
| **Transaction** | Група DB operations, яка або виконується повністю, або відкочується; гарантує цілісність |
| **TransactionTestCase** | Django клас: не загортає в транзакцію → дані видимі з усіх потоків. Обов'язковий для async consumer тестів |

## U

| Термін | Пояснення |
|--------|-----------|
| **unique_together** | Meta.unique_together або `UniqueConstraint`: комбінація полів унікальна в межах таблиці |
| **URLRouter** | Channels: маршрутизує WebSocket з'єднання до Consumer за URL патерном |
| **Uvicorn** | ASGI server на Python: запускає Django ASGI application. В docker stack: `uvicorn notes_project.asgi:application` |

## V

| Термін | Пояснення |
|--------|-----------|
| **View** | Обробник HTTP request/response. FBV (функція) або CBV (клас). У Notes Chat App — переважно FBV |

## W

| Термін | Пояснення |
|--------|-----------|
| **WebsocketCommunicator** | `channels.testing` клас для юніт-тестування WebSocket consumer без реального браузера і сервера |
| **WebSocket** | Протокол: довге двостороннє з'єднання між браузером і сервером (на відміну від HTTP request/response) |
| **worker thread** | Окремий потік у Django thread pool, де `database_sync_to_async` виконує синхронний ORM код |
| **WSGI** | Web Server Gateway Interface: класичний sync Python web interface. Не підтримує WebSocket |
