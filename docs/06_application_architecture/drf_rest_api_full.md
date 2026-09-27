# Django REST Framework — REST API на Django

> **Для кого:** студенти, які вже мають Django-застосунок з моделями, views і шаблонами (Частини II–V) і хочуть віддати ті самі дані **програмам**: мобільному застосунку, фронтенду на JavaScript, Telegram-боту, дашборду.
>
> **Головне питання глави:** як додати до Django REST API так, щоб він був безпечним (кожен бачить лише свої дані), тонким (без бізнес-логіки у view) і узгодженим з рештою застосунку?
>
> **Передумови:** [Django ORM](../03_database_and_orm/django_orm_full.md), [Views](../02_django_core/views_full.md), [Services та Selectors](services_selectors_full.md), HTTP-методи й статус-коди ([HTTP та HTTPS](../01_web_foundations/http_https.md)).
> **Рівень:** Intermediate.
> **Пов'язані глави:** [Serializers — Transport Layer](django_serializers_full.md) (Input/Output-серіалізатори поглиблено), [Django Ninja](django_ninja_templates_full.md) (альтернатива DRF), [Права доступу](../07_auth_and_security/permissions_full.md).

---

## Яку проблему вирішує тема

Django-view з [Частини II](../02_django_core/views_full.md) повертає HTML: `render(request, "note_list.html", context)`. Браузеру цього досить. Але мобільному застосунку, JavaScript-фронтенду чи боту HTML не потрібен — їм потрібен **JSON** і передбачуваний **REST API**: ресурси з адресами, HTTP-методи за призначенням, чесні статус-коди.

Написати API на «голому» Django можна:

```python
import json
from django.http import JsonResponse

def note_list_api(request):
    if request.method == "GET":
        notes = [{"id": n.id, "title": n.title} for n in Note.objects.filter(user=request.user)]
        return JsonResponse(notes, safe=False)
    if request.method == "POST":
        data = json.loads(request.body)          # а якщо не JSON?
        if not data.get("title"):                # а решта полів? довжина? тип?
            return JsonResponse({"error": "title required"}, status=400)
        ...                                      # і так для кожного ресурсу й методу
```

Кожен ендпоінт повторює те саме: розібрати тіло, перевірити поля, перетворити модель на словник, обрати код відповіді, перевірити права, розбити список на сторінки. **Django REST Framework (DRF)** забирає цю рутину:

| Рутина | Що дає DRF |
|---|---|
| модель ↔ JSON, перевірка вхідних даних | **серіалізатори** |
| розбір тіла будь-якого формату | `request.data` (парсери JSON, form, multipart) |
| JSON чи HTML-сторінка для людини | `Response` + **рендерери** і content negotiation |
| CRUD для ресурсу | **ViewSet** і **роутер** |
| хто ти і що тобі можна | **authentication** і **permissions** |
| сторінки, фільтри, обмеження частоти | pagination, filtering, throttling |

---

## Ментальна модель

DRF — **перекладач на межі застосунку**. Усередині — моделі, selectors, services, звичайний Python. Назовні — HTTP і JSON. Між ними DRF:

- **на вході** перевіряє, *хто* прийшов (authentication), *чи можна* (permissions) і *чи правильні дані* (serializer);
- **на виході** перетворює Python-об'єкти на JSON (serializer + renderer).

Бізнес-логіки в DRF-шарі бути не повинно: як і звичайна view, **ViewSet лише координує** (див. [Services та Selectors](services_selectors_full.md)).

```mermaid
flowchart TD
    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    C["клієнт: мобільний застосунок,<br>JS-фронтенд, бот"] -- "HTTP + JSON" --> R["роутер<br>/api/notes/"]
    R --> V["ViewSet<br>координує"]
    V --> A["authentication<br>хто ти?"]
    V --> P["permissions<br>чи можна?"]
    V --> S["serializer<br>JSON ↔ Python, валідація"]
    V --> SEL["selectors<br>читання"]
    V --> SRV["services<br>зміни"]
    SEL --> M["моделі, ORM"]
    SRV --> M

    class C step
    class R,V success
    class A,P,S warning
    class SEL,SRV,M step
```

---

## Основні поняття

| Поняття | Що це | Аналог у звичайному Django |
|---|---|---|
| `Request` | обгортка над `HttpRequest`: `request.data`, `request.query_params`, `request.user` | `request.POST`, `request.GET` |
| `Response` | відповідь з Python-даними; формат обирає рендерер | `JsonResponse` / `render` |
| **Serializer** | опис полів: перетворення й валідація | `Form` |
| **ModelSerializer** | серіалізатор, що бере поля з моделі | `ModelForm` |
| `APIView` | клас-view з автентифікацією, правами, обробкою винятків | `View` |
| generic views | готові `ListCreateAPIView`, `RetrieveUpdateDestroyAPIView` | `ListView`, `UpdateView` |
| **ViewSet** | один клас з діями `list`, `create`, `retrieve`, `update`, `partial_update`, `destroy` | кілька view |
| **Router** | будує URL-и з ViewSet | ручні `path()` |
| `@action` | власна дія ViewSet: `/api/notes/{id}/pin/` | окрема view |
| Authentication | визначає `request.user`: сесія, токен, JWT | `AuthenticationMiddleware` |
| Permission | вирішує, чи можна виконати дію | `@login_required`, перевірки у view |
| Pagination | ділить список на сторінки | `Paginator` |
| Renderer | Python-дані → JSON або HTML (browsable API) | шаблон |

---

## Як механізм працює всередині

Кожна DRF-view — нащадок `APIView`. Його метод `dispatch()` робить для кожного запиту одне й те саме:

```mermaid
flowchart TD
    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    D["dispatch(request)"] --> INIT["initialize_request<br>HttpRequest → Request"]
    INIT --> AUTH{"perform_authentication<br>хто ти?"}
    AUTH --> PERM{"check_permissions<br>можна цю дію?"}
    PERM -- ні --> E403["403 / 401<br>NotAuthenticated, PermissionDenied"]
    PERM -- так --> TH{"check_throttles<br>не надто часто?"}
    TH -- ні --> E429["429 Throttled"]
    TH -- так --> H["handler: list / create / pin …"]
    H --> OBJ{"get_object → check_object_permissions<br>саме цей об'єкт можна?"}
    OBJ -- ні --> E404["404 / 403"]
    OBJ -- так --> RESP["Response(data)"]
    H -- "ValidationError у serializer" --> E400["400 + помилки за полями"]
    RESP --> REND["finalize_response:<br>рендерер JSON або HTML"]

    class D,INIT,H,RESP step
    class AUTH,PERM,TH,OBJ decision
    class E403,E429,E404,E400 error
    class REND success
```

Важливі наслідки:

- **Винятки стають відповідями.** `raise NotFound(...)`, `raise ValidationError(...)`, `raise PermissionDenied(...)` у будь-якому місці handler-а DRF перехоплює і перетворює на `404`, `400`, `403` з JSON-тілом `{"detail": …}` або помилками за полями.
- **Перевірка прав — двох рівнів.** `has_permission()` — до handler-а («чи може цей користувач взагалі створювати нотатки»), `has_object_permission()` — лише коли handler викликає `get_object()` («чи може саме цю нотатку»). Якщо ти не використовуєш `get_object()`, об'єктну перевірку треба зробити самому — див. «Типові помилки».
- **`401` чи `403`.** Коли автентифікації немає, DRF повертає `401` лише якщо **перший** клас у `DEFAULT_AUTHENTICATION_CLASSES` уміє попросити облікові дані заголовком `WWW-Authenticate` (`BasicAuthentication`, `TokenAuthentication`). Із `SessionAuthentication` першою — `403`.
- **Content negotiation.** Один і той самий `Response` DRF віддає як JSON (`Accept: application/json`, `curl`) або як HTML-сторінку browsable API (браузер).

---

## Повний lifecycle

Запит `POST /api/notes/` від користувача, що увійшов:

```mermaid
sequenceDiagram
    participant C as клієнт
    participant U as urls.py + router
    participant V as NoteViewSet
    participant A as auth + permissions
    participant IS as NoteInputSerializer
    participant SRV as services.create_note
    participant DB as PostgreSQL
    participant OS as NoteOutputSerializer
    C->>U: POST /api/notes/ {"title": "Нотатка Боба", "priority": 4}
    U->>V: dispatch → create(request)
    V->>A: SessionAuthentication, IsAuthenticated
    A-->>V: request.user = bob
    V->>IS: NoteInputSerializer(data=request.data)
    IS->>IS: is_valid(): title ≤ 200, priority ∈ 1..4
    alt дані неправильні
        IS-->>C: 400 {"priority": ["…не є коректним вибором."]}
    else дані правильні
        V->>SRV: create_note(user=request.user, **validated_data)
        SRV->>DB: INSERT (transaction.atomic)
        DB-->>SRV: Note
        V->>OS: NoteOutputSerializer(note).data
        OS-->>C: 201 {"id": 3, "title": "Нотатка Боба", …}
    end
```

Зверни увагу: **власника задає сервер** (`user=request.user`), а не клієнт. Поле `user` у тілі запиту вхідний серіалізатор просто не приймає.

---

## Мінімальний незалежний приклад

Навчальний проєкт `hello_project` з уроків 33 і 35 [курсу](https://nikoriakviktot.github.io/PY-Course-Victor-Nikoriak-22-09-2026/modules/m4/lesson_35/) — модель `Note` без власника, API «як з коробки». Повний код: [`lesson_35_drf_fastapi/hello_project`](https://github.com/NikoriakViktot/PY-Course-Victor-Nikoriak-22-09-2026/tree/main/module_4/lessons/lesson_35_drf_fastapi/hello_project).

**1. Встановлення і налаштування.**

```bash
pip install djangorestframework drf-spectacular
```

```python
# hello_project/settings.py
INSTALLED_APPS = [
    # ...
    "rest_framework",
    "drf_spectacular",
    "hello_app",
]

REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 3,
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.BasicAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticatedOrReadOnly"],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}
```

**2. Серіалізатор.**

```python
# hello_app/serializers.py
from rest_framework import serializers
from .models import Note


class NoteSerializer(serializers.ModelSerializer):
    priority_label = serializers.CharField(source="get_priority_display", read_only=True)

    class Meta:
        model = Note
        fields = ["id", "title", "content", "is_pinned", "priority", "priority_label", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_title(self, value):
        value = value.strip()
        if len(value) < 3:
            raise serializers.ValidationError("Заголовок має містити щонайменше 3 символи.")
        return value
```

У `python manage.py shell` (Django 5.2.17, DRF 3.18.1):

```python
>>> good = NoteSerializer(data={"title": "  Прочитати про REST  ", "priority": 4, "id": 999})
>>> good.is_valid(), good.validated_data
(True, {'title': 'Прочитати про REST', 'priority': 4})
>>> bad = NoteSerializer(data={"title": "ok", "priority": 7})
>>> bad.is_valid(); bad.errors
False
{'title': [ErrorDetail(string='Заголовок має містити щонайменше 3 символи.', code='invalid')], 'priority': [ErrorDetail(string='"7" не є коректним вибором.', code='invalid_choice')]}
```

`id: 999` проігноровано — поле лише для читання; пробіли прибрав `validate_title`; помилки зібрано для всіх полів одразу.

**3. ViewSet і роутер.**

```python
# hello_app/api.py
from rest_framework import viewsets
from .models import Note
from .serializers import NoteSerializer


class NoteViewSet(viewsets.ModelViewSet):
    queryset = Note.objects.all()
    serializer_class = NoteSerializer
```

```python
# hello_project/urls.py
from rest_framework.routers import DefaultRouter
from hello_app.api import NoteViewSet

router = DefaultRouter()
router.register("notes", NoteViewSet, basename="note")

urlpatterns = [
    # ...
    path("api/", include(router.urls)),
]
```

Два рядки ViewSet — і `GET/POST /api/notes/`, `GET/PUT/PATCH/DELETE /api/notes/{id}/`. Реальні відповіді з `runserver` (фрагменти):

```text
$ curl -s -X POST http://127.0.0.1:8000/api/notes/ -H "Content-Type: application/json" -d '{"title": "Без входу"}' -w "\n%{http_code}\n"
{"detail":"Реквізити перевірки достовірності не надані."}
403
$ curl -s -u admin:lesson33-pass -X POST http://127.0.0.1:8000/api/notes/ -H "Content-Type: application/json" -d '{"title": "ok", "priority": 9}' -w "\n%{http_code}\n"
{"title":["Заголовок має містити щонайменше 3 символи."],"priority":["\"9\" не є коректним вибором."]}
400
$ curl -s -u admin:lesson33-pass -X DELETE http://127.0.0.1:8000/api/notes/4/ -o /dev/null -w "%{http_code}\n"
204
```

Для навчального проєкту без користувачів цього досить. Для застосунку, де кожна нотатка має власника, — **ні**: `Note.objects.all()` у ViewSet віддав би кожному всі нотатки. Як це зробити правильно — у наступному розділі.

---

## Приклад із Notes Chat App

!!! warning "Стан коду"
    У поточному коді Notes Chat App **REST API немає**: застосунок працює через HTML-views, форми й WebSocket-чат. Нижче — як додати API **поверх наявних** `selectors.py` і `services.py`, нічого в них не змінюючи. Код перевірено на копії репозиторію (Django 5.2.17, DRF 3.18.1, PostgreSQL 16): тести й вивід нижче — справжні.

У Notes Chat App вже є все, що потрібно API:

| Потреба API | Що вже є в коді |
|---|---|
| нотатки користувача і його груп, пошук | `selectors.get_user_notes(user, *, archived=False, notebook=None, tag=None, search=None)` |
| одна нотатка з перевіркою доступу | `selectors.get_note_detail(user, note_id)` — кидає `Note.DoesNotExist` для чужої |
| створення з транзакцією і тегами | `services.create_note(*, user, title, content='', notebook=None, priority=1, group=None, tag_ids=None)` |
| закріпити / відкріпити | `services.toggle_pin_note(note)` |

Тому ViewSet лише координує — і **не використовує** `Note.objects` напряму:

```python
# notes_app/api.py
from rest_framework import permissions, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from . import selectors, services
from .models import Note


class NoteOutputSerializer(serializers.ModelSerializer):
    """Що бачить клієнт: явний список полів, без user і group."""
    priority_label = serializers.CharField(source="get_priority_display", read_only=True)
    notebook = serializers.CharField(source="notebook.title", default=None, read_only=True)

    class Meta:
        model = Note
        fields = ["id", "title", "content", "priority", "priority_label", "is_pinned", "notebook"]


class NoteInputSerializer(serializers.Serializer):
    """Що клієнт може надіслати. Власника задає сервер, а не клієнт."""
    title = serializers.CharField(max_length=200)
    content = serializers.CharField(required=False, allow_blank=True, default="")
    priority = serializers.ChoiceField(choices=Note.PRIORITY_CHOICES, default=Note.PRIORITY_LOW)


class NoteViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    def _get_note(self, request, pk):
        try:
            return selectors.get_note_detail(request.user, pk)
        except Note.DoesNotExist:
            raise NotFound("Нотатку не знайдено.")

    def list(self, request):
        notes = selectors.get_user_notes(request.user, search=request.query_params.get("search"))
        return Response(NoteOutputSerializer(notes, many=True).data)

    def retrieve(self, request, pk=None):
        return Response(NoteOutputSerializer(self._get_note(request, pk)).data)

    def create(self, request):
        data = NoteInputSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        note = services.create_note(user=request.user, **data.validated_data)
        return Response(NoteOutputSerializer(note).data, status=201)

    @action(detail=True, methods=["post"])
    def pin(self, request, pk=None):
        note = services.toggle_pin_note(self._get_note(request, pk))
        return Response(NoteOutputSerializer(note).data)
```

Підключення — у `notes_project/settings.py` і `notes_project/urls.py`:

```python
# notes_project/settings.py
INSTALLED_APPS = [
    # ... "channels",
    "rest_framework",
    "notes_app",
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": ["rest_framework.authentication.SessionAuthentication"],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
}
```

```python
# notes_project/urls.py
from rest_framework.routers import DefaultRouter
from notes_app.api import NoteViewSet

router = DefaultRouter()
router.register("notes", NoteViewSet, basename="api-note")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(router.urls)),
    # ...
]
```

Чому саме так:

- **`viewsets.ViewSet`, а не `ModelViewSet`.** `ModelViewSet` будує все навколо `queryset` і `serializer.save()` — логіка створення потрапила б у серіалізатор, повз `services.create_note` з його транзакцією й перевіркою тегів. `ViewSet` з явними `list`/`create` лишає правила там, де вони вже є.
- **Два серіалізатори.** Вхідний описує, що клієнт *може надіслати* (без `user`, `group`, `is_pinned`); вихідний — що він *побачить*. Детально — у главі [Serializers — Transport Layer](django_serializers_full.md).
- **Доступ перевіряє selector.** `get_note_detail` фільтрує `Q(user=user) | Q(group__in=user_groups)` — чужа нотатка для API просто не існує, тому `404`, а не `403`: так клієнт навіть не дізнається, що такий `id` є.

Сценарій: Аліса й Боб у групі «Сім'я»; в Аліси одна особиста й одна групова нотатка. Запити тестовим клієнтом DRF (`APIClient`):

```python
client = APIClient()
print(client.get("/api/notes/").status_code, client.get("/api/notes/").data)
client.force_authenticate(bob)
print([n["title"] for n in client.get("/api/notes/").data])
print(client.get(f"/api/notes/{private.pk}/").status_code, client.get(f"/api/notes/{private.pk}/").data)
created = client.post("/api/notes/", {"title": "Нотатка Боба", "priority": 4, "user": alice.pk}, format="json")
print(created.status_code, created.data)
print("власник:", Note.objects.get(pk=created.data["id"]).user.username)
client.force_authenticate(alice)
print([n["title"] for n in client.get("/api/notes/").data])
print(client.post(f"/api/notes/{private.pk}/pin/").data["is_pinned"])
```

```text
403 {'detail': ErrorDetail(string='Реквізити перевірки достовірності не надані.', code='not_authenticated')}
['Список покупок']
404 {'detail': ErrorDetail(string='Нотатку не знайдено.', code='not_found')}
201 {'id': 3, 'title': 'Нотатка Боба', 'content': '', 'priority': 4, 'priority_label': '🔴 Терміново', 'is_pinned': False, 'notebook': None}
власник: bob
['Список покупок', 'Особиста нотатка Аліси']
True
```

- Боб бачить лише групову нотатку; особиста нотатка Аліси для нього — `404`.
- Боб спробував надіслати `"user": alice.pk` — поле проігноровано, власник — `bob`.
- Нотатки Боба немає в списку Аліси: вона не групова.

Тести — у стилі [Частини VIII](../08_testing_and_quality/django_testing_full.md):

```python
# notes_app/tests/test_api.py
from django.contrib.auth.models import Group, User
from rest_framework.test import APITestCase

from notes_app import services


class NoteApiTests(APITestCase):
    def setUp(self):
        self.alice = User.objects.create_user("alice", password="pass-alice")
        self.bob = User.objects.create_user("bob", password="pass-bob")
        self.family = Group.objects.create(name="Сім'я")
        self.alice.groups.add(self.family)
        self.bob.groups.add(self.family)
        self.private = services.create_note(user=self.alice, title="Особиста нотатка Аліси")
        self.shared = services.create_note(user=self.alice, title="Список покупок", group=self.family)

    def test_login_required(self):
        self.assertEqual(self.client.get("/api/notes/").status_code, 403)

    def test_bob_sees_only_group_notes(self):
        self.client.force_authenticate(self.bob)
        titles = [n["title"] for n in self.client.get("/api/notes/").data]
        self.assertEqual(titles, ["Список покупок"])
        self.assertEqual(self.client.get(f"/api/notes/{self.private.pk}/").status_code, 404)

    def test_create_sets_owner_from_request(self):
        self.client.force_authenticate(self.bob)
        response = self.client.post("/api/notes/", {"title": "Нотатка Боба", "priority": 4}, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data["priority_label"], "🔴 Терміново")
        self.assertEqual(services.Note.objects.get(pk=response.data["id"]).user, self.bob)

    def test_pin_toggles(self):
        self.client.force_authenticate(self.alice)
        first = self.client.post(f"/api/notes/{self.private.pk}/pin/").data["is_pinned"]
        second = self.client.post(f"/api/notes/{self.private.pk}/pin/").data["is_pinned"]
        self.assertEqual((first, second), (True, False))
```

```text
$ DATABASE_URL=postgres://notes:notes@localhost:5432/notes_api_demo python manage.py test notes_app.tests.test_api
Creating test database for alias 'default'...
System check identified no issues (0 silenced).
....
----------------------------------------------------------------------
Ran 4 tests in 2.099s

OK
Destroying test database for alias 'default'...
```

---

## Типові помилки

### 1. `ModelViewSet` з `Note.objects.all()` у застосунку з власниками

```python
class NoteViewSet(viewsets.ModelViewSet):
    queryset = Note.objects.all()          # ❌ кожен бачить і змінює ВСІ нотатки
    serializer_class = NoteSerializer
    permission_classes = [IsAuthenticated]
```

`IsAuthenticated` перевіряє лише, що користувач **увійшов**, а не що нотатка **його**. `GET /api/notes/17/` віддасть чужу нотатку — це IDOR (Insecure Direct Object Reference, див. [Права доступу](../07_auth_and_security/permissions_full.md)). Виправлення: queryset з обмеженням на користувача — `get_queryset()`, що викликає selector, або явна перевірка, як у прикладі вище.

### 2. `fields = "__all__"`

`ModelSerializer` з `"__all__"` для `User` віддає хеш пароля, `is_superuser`, `is_staff` — і на запис дозволив би їх змінити. Для `Note` — відкриває `user` і `group`: клієнт зміг би створити нотатку від чужого імені. **Завжди явний список полів**, а краще — окремі вхідний і вихідний серіалізатори.

### 3. `serializer.save()` без `is_valid()`

```python
serializer = NoteInputSerializer(data=request.data)
serializer.save()      # AssertionError: You must call `.is_valid()` before calling `.save()`.
```

Правильно: `serializer.is_valid(raise_exception=True)` — DRF сам поверне `400` з помилками.

### 4. Бізнес-логіка в серіалізаторі

`def create(self, validated_data)` у серіалізаторі, що надсилає листи, створює нагадування й теги, — та сама проблема, що й fat view. Серіалізатор — межа транспорту: перевірити й перетворити дані. Зміни стану — у `services.py`.

### 5. Очікують `401`, отримують `403`

Див. «Як механізм працює всередині»: код залежить від **першого** класу автентифікації. Для API з токенами (`TokenAuthentication` першою) буде `401` з `WWW-Authenticate: Token`.

### 6. `SessionAuthentication` і CSRF

Із сесійною автентифікацією DRF вимагає CSRF-токен для `POST`/`PUT`/`PATCH`/`DELETE`. Браузерний фронтенд на тому самому домені передає його заголовком `X-CSRFToken`. Мобільний застосунок сесію й CSRF не використовує — йому потрібна токенна автентифікація (Частина VII).

---

## Debugging

| Симптом | Що перевірити |
|---|---|
| `400`, незрозуміло чому | тіло відповіді: DRF пише помилку для кожного поля; у shell — `serializer.is_valid(); serializer.errors` |
| `403` без пояснень | чи увійшов користувач (`request.user`), `DEFAULT_PERMISSION_CLASSES`, CSRF для сесійної автентифікації |
| `404` на існуючий `id` | selector / `get_queryset()` фільтрує за користувачем — так і має бути для чужих об'єктів |
| `404` на весь `/api/` | `include(router.urls)` у `urls.py`; `print(router.urls)` покаже всі згенеровані маршрути |
| повільний список | кількість SQL-запитів: `django.db.connection.queries` при `DEBUG=True`; debug toolbar не вбудовується в JSON-відповіді, але працює на сторінках browsable API |
| поле не з'являється у відповіді | чи є воно у `Meta.fields`; для `source="notebook.title"` — чи не `None` зв'язок (потрібен `default=None`) |

**Browsable API** — найшвидший спосіб налагодження: відкрий `/api/notes/` у браузері, увійшовши через `/accounts/login/`, — побачиш відповідь, заголовки й форму для `POST`.

---

## Security implications

- **Об'єктний доступ — найважливіше.** Кожен запит до конкретного об'єкта має проходити через перевірку власника / групи. У Notes Chat App цю роль уже виконують selectors з `Q(user=user) | Q(group__in=…)` — API має використовувати їх, а не `Note.objects`.
- **Власник — з `request.user`, ніколи з тіла запиту.**
- **Явні поля** у серіалізаторах; окремі вхідні й вихідні серіалізатори.
- **Автентифікація для API:** сесії — для браузера на тому самому домені (з CSRF); токени / JWT — для мобільних і сторонніх клієнтів, лише через HTTPS (Частина VII, [OWASP Top 10](../07_auth_and_security/owasp_top_10_full.md): A01 Broken Access Control, A07 Identification and Authentication Failures).
- **Throttling** (`DEFAULT_THROTTLE_CLASSES`, `DEFAULT_THROTTLE_RATES`) — обмеження частоти для перебору паролів і скриптів.
- **Browsable API у production** можна вимкнути, залишивши лише `JSONRenderer` у `DEFAULT_RENDERER_CLASSES`.

---

## Performance implications

- **N+1 у серіалізаторах.** Поле `notebook = CharField(source="notebook.title")` звертається до зв'язку для **кожної** нотатки. `selectors.get_user_notes` уже робить `select_related('notebook', 'group')` і `prefetch_related('tags')` — тому список з будь-якою кількістю нотаток виконує фіксовану кількість запитів. Детально — [Оптимізація запитів](../03_database_and_orm/query_optimization.md).
- **Пагінація.** Список без пагінації віддає всі записи; для великих колекцій — `PageNumberPagination` або `CursorPagination` (стабільна при додаванні записів).
- **Серіалізація не безкоштовна.** `ModelSerializer` на тисячах об'єктів помітно повільніший за `values()`; для важких звітів — окремий selector, що повертає словники.

---

## Архітектурні наслідки

**Одна модель — три входи.** HTML-views, адмінка і API працюють з тими самими моделями й **тими самими selectors/services**. Правило «view лише координує» тепер означає: і `views.py`, і `api.py` — тонкі, логіка — одна.

```mermaid
flowchart TD
    classDef step     fill:#eceff1,stroke:#546e7a,stroke-width:1px;
    classDef decision fill:#e3f2fd,stroke:#1565c0,stroke-width:2px;
    classDef success  fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px;
    classDef error    fill:#ffebee,stroke:#c62828,stroke-width:3px;
    classDef warning  fill:#fff8e1,stroke:#e65100,stroke-width:2px;

    B["браузер"] --> VW["views.py<br>HTML, форми"]
    MOB["мобільний застосунок,<br>JS, бот"] --> API["api.py<br>DRF ViewSet"]
    ST["персонал"] --> ADM["admin.py"]
    VW --> SEL["selectors.py"]
    API --> SEL
    VW --> SRV["services.py"]
    API --> SRV
    SEL --> M["models.py"]
    SRV --> M
    ADM --> M

    class B,MOB,ST step
    class VW,API,ADM success
    class SEL,SRV warning
    class M decision
```

**DRF, Django Ninja чи FastAPI** — див. також порівняння в главі [Django Ninja](django_ninja_templates_full.md):

| | DRF | Django Ninja | FastAPI |
|---|---|---|---|
| Основа | Django | Django | Starlette, окремо від Django |
| Валідація | серіалізатори | Pydantic-схеми за типами | Pydantic |
| CRUD | ViewSet + роутер | функції з декораторами | функції з декораторами |
| OpenAPI / Swagger | пакет (drf-spectacular) | з коробки | з коробки |
| Async | обмежено | так | так |
| Екосистема | найбільша: фільтри, JWT, throttling, документація | менша | велика, але поза Django |
| Коли | великий Django-проєкт, багато стандартного CRUD, команда знає DRF | Django-проєкт, хочеться типів і async | окремий API-сервіс без Django |

---

## Контрольні питання

1. Які дві роботи виконує серіалізатор? Чим `Serializer` відрізняється від `ModelSerializer`?
2. Що робить `APIView.dispatch()` до виклику handler-а?
3. Чим `has_permission()` відрізняється від `has_object_permission()`? Коли друга не викликається?
4. Чому в Notes Chat App API краще будувати на `viewsets.ViewSet` із selectors/services, а не на `ModelViewSet`?
5. Чому чужа нотатка повертає `404`, а не `403`?
6. Від чого залежить, чи отримає неавтентифікований клієнт `401` чи `403`?
7. Як `select_related` у selector-і впливає на швидкість серіалізації списку?
8. Коли обрати DRF, а коли — Django Ninja або FastAPI?

??? success "Відповіді"

    1. Перетворення об'єктів у JSON-сумісні дані й перевірка та перетворення вхідних даних. `Serializer` — поля описуємо самі; `ModelSerializer` бере їх з моделі й уміє `create`/`update`.
    2. Обгортає `HttpRequest` у `Request`, виконує автентифікацію, перевіряє права й throttling; винятки перетворює на відповіді.
    3. Перша — для дії загалом (до handler-а), друга — для конкретного об'єкта, лише коли handler викликає `get_object()`. У власних handler-ах без `get_object()` об'єктну перевірку робить selector.
    4. Щоб створення й зміни йшли через `services` (транзакції, перевірка тегів), а читання — через `selectors` з обмеженням доступу; логіка не дублюється між HTML-views і API.
    5. Selector не знаходить нотатку поза доступом користувача; `404` не розкриває, що такий `id` існує.
    6. Від першого класу в `DEFAULT_AUTHENTICATION_CLASSES`: якщо він задає `WWW-Authenticate` (Basic, Token) — `401`, інакше (Session) — `403`.
    7. Без нього кожна нотатка робить окремий запит за блокнотом (N+1); із ним — один `JOIN` на весь список.
    8. DRF — великий Django-проєкт зі стандартним CRUD і потрібною екосистемою; Ninja — Django-проєкт з типами й async; FastAPI — окремий API-сервіс без Django.

---

## Що читати далі

- [Serializers — Transport Layer](django_serializers_full.md) — Input/Output-серіалізатори, порядок валідації, перетворення помилок домену на HTTP.
- [Права доступу](../07_auth_and_security/permissions_full.md) і [OWASP Top 10](../07_auth_and_security/owasp_top_10_full.md) — IDOR і контроль доступу.
- [Django Testing](../08_testing_and_quality/django_testing_full.md) — `APITestCase` і тестова база.
- [Django Ninja](django_ninja_templates_full.md) — альтернативний підхід до API на Django.
- Курс: [урок 35 «DRF overview + Django vs FastAPI»](https://nikoriakviktot.github.io/PY-Course-Victor-Nikoriak-22-09-2026/modules/m4/lesson_35/) — покроково, з `curl`, browsable API, OpenAPI і тим самим API на FastAPI.
- Документація: [Django REST framework](https://www.django-rest-framework.org/), [drf-spectacular](https://drf-spectacular.readthedocs.io/).
