# Django Services — the business logic layer

> `services.py` is a separate file in every Django app
> where all the business logic lives.
> A service is a **transport-agnostic function that describes what the system does**.

---

## The problem without Services

In a typical Django project, business logic gradually settles into the View:

```python
# views.py — the "Fat View" anti-pattern
class RegisterUserView(APIView):

    def post(self, request):
        # validation
        if User.objects.filter(email=request.data['email']).exists():
            return Response({'error': 'Email вже зайнятий'}, status=400)

        # password hashing
        password = make_password(request.data['password'])

        # saving
        user = User.objects.create(
            email=request.data['email'],
            password=password,
        )

        # sending an email
        send_welcome_email(user.email)

        # response
        return Response({'id': user.id}, status=201)
```

**What breaks:**
- This logic cannot be reused from a Celery task
- It cannot be called from a management command
- It cannot be tested without an HTTP request
- The logic is duplicated if registration is needed in two places

---

## The solution: a Service

```python
# apps/users/services.py

def user_create(*, email: str, password: str) -> User:
    user = User(email=email)
    user.set_password(password)
    user.full_clean()
    user.save()
    send_welcome_email(user.email)
    return user
```

```python
# views.py — thin, no logic
class RegisterUserView(APIView):

    def post(self, request):
        serializer = UserRegisterInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = user_create(**serializer.validated_data)

        return Response({'id': user.id}, status=201)
```

The same logic is now available from anywhere:

```python
# From a Celery task
user_create(email='bot@example.com', password='secret')

# From a management command
user_create(email='admin@example.com', password='admin123')

# From a test
user = user_create(email='test@example.com', password='pass')
assert user.id is not None
```

---

## What a Service is architecturally

A service is the **layer between the HTTP transport and the database** that describes the business domain.

```
Transport Layer     views.py, tasks.py, management commands
        │
        │  validated_data / parameters
        ▼
Application Layer   services.py          ← THE LOGIC LIVES HERE
        │
        │  domain objects
        ▼
Data Layer          selectors.py, models.py, ORM
        │
        ▼
     PostgreSQL
```

| Layer | Answers the question |
|-----|-----------------------|
| View | How did the request arrive? HTTP, WebSocket, CLI? |
| **Service** | **What does the system do with this data?** |
| Selector | How do we get the needed data from the DB? |
| ORM | How do we formulate the SQL? |

---

## Anatomy of a Service

### Basic rules

- Lives in `<app_name>/services.py`
- A stateless Python function (not a class, unless there is complex state)
- Keyword-only arguments (`*`) — protection against argument-order mistakes during refactoring
- Strict type annotations
- Knows nothing about HTTP — does not import `request`, does not return `Response`
- Returns a domain object or None

```python
# apps/flood/services.py

from django.db import transaction
from apps.flood.models import FloodEvent


def flood_event_create(
    *,
    region_name: str,
    severity_level: str,
    detected_at,
    created_by,
) -> FloodEvent:
    event = FloodEvent(
        region_name=region_name,
        severity_level=severity_level,
        detected_at=detected_at,
        created_by=created_by,
    )
    event.full_clean()   # Django validation at the domain level
    event.save()
    return event


def flood_event_update(
    *,
    event: FloodEvent,
    severity_level: str,
) -> FloodEvent:
    event.severity_level = severity_level
    event.full_clean()
    event.save(update_fields=['severity_level'])
    return event


def flood_event_delete(*, event: FloodEvent) -> None:
    event.delete()
```

> The `*` before the arguments is Python syntax for keyword-only parameters.
> It can only be called like this: `flood_event_create(region_name="Kyiv", ...)`.
> The order of arguments does not matter — there is no risk of mixing them up.

---

## Transactions

The Service is responsible for transaction boundaries. If several operations must be atomic, the whole function is wrapped in `@transaction.atomic`.

```python
def user_complete_onboarding(*, user: User) -> User:
    # Without atomic — if the second operation fails,
    # the first one has already run and will not be rolled back
    user.onboarding_completed = True
    user.save(update_fields=['onboarding_completed'])

    profile = UserProfile(user=user, bio='')
    profile.save()

    return user
```

```python
@transaction.atomic
def user_complete_onboarding(*, user: User) -> User:
    # With atomic — either everything is saved, or nothing
    user.onboarding_completed = True
    user.save(update_fields=['onboarding_completed'])

    profile = UserProfile(user=user, bio='')
    profile.save()

    return user
```

### When you need `@transaction.atomic`

| Situation | Atomic? |
|----------|---------|
| A single `save()` | No — Django is atomic on its own at the row level |
| Two or more `save()` calls | Yes |
| `save()` + `delete()` | Yes |
| Any related operations that must all happen or none at all | Yes |

---

## Side Effects and `on_commit`

A **side effect** is an action outside the main transaction: sending an email, a Celery task, a write to an external API.

### The problem without `on_commit`

```python
@transaction.atomic
def flood_event_create(*, region_name: str, ...) -> FloodEvent:
    event = FloodEvent(...)
    event.save()

    # DANGEROUS — Celery will receive the task before
    # the transaction has closed and the record has appeared in the DB.
    # The worker will try to find the event — and won't find it.
    notify_emergency_task.delay(event.id)

    return event
```

### The solution: `transaction.on_commit`

```python
@transaction.atomic
def flood_event_create(*, region_name: str, ...) -> FloodEvent:
    event = FloodEvent(...)
    event.save()

    # SAFE — the task starts ONLY after a successful commit.
    # If the transaction is rolled back, the task will not start at all.
    transaction.on_commit(
        lambda: notify_emergency_task.delay(event.id)
    )

    return event
```

### The rule

```
on_commit → a guarantee that the side effect
            happens only if the data was actually saved to the DB
```

---

## A Celery Task is also the Transport Layer

A Celery task is a delivery queue, not a place for logic. The task delegates to a Service.

```python
# apps/flood/tasks.py

# BAD — logic directly in the task
@shared_task
def process_flood_task(event_id: int):
    event = FloodEvent.objects.get(id=event_id)
    event.status = 'processed'
    event.save()
    send_report_email(event.created_by.email)
```

```python
# GOOD — the task only transports the call
@shared_task
def process_flood_task(event_id: int):
    from apps.flood.selectors import flood_event_get_by_id
    from apps.flood.services import flood_event_mark_processed

    event = flood_event_get_by_id(event_id=event_id)
    flood_event_mark_processed(event=event)
```

The same `flood_event_mark_processed` can be called from a View, a test or the CLI — without changing the logic.

---

## Mapping domain errors to HTTP

A Service knows nothing about HTTP. But if `full_clean()` raises `django.core.exceptions.ValidationError`, DRF does not know how to format it into a 400 response.

The solution is a custom exception handler (once, in `settings.py`):

```python
# shared/exceptions/handlers.py

from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework.views import exception_handler
from rest_framework.exceptions import ValidationError as DRFValidationError
from rest_framework.serializers import as_serializer_error


def custom_exception_handler(exc, context):
    if isinstance(exc, DjangoValidationError):
        exc = DRFValidationError(detail=as_serializer_error(exc))

    return exception_handler(exc, context)
```

```python
# settings.py
REST_FRAMEWORK = {
    'EXCEPTION_HANDLER': 'shared.exceptions.handlers.custom_exception_handler',
}
```

Now `full_clean()` in any Service automatically returns a nice JSON 400 to the client.

---

## Full example: View → Service

### Model

```python
# apps/flood/models.py

class FloodEvent(models.Model):
    SEVERITY_CHOICES = [('low', 'Low'), ('medium', 'Medium'), ('high', 'High')]

    region_name    = models.CharField(max_length=200)
    severity_level = models.CharField(max_length=20, choices=SEVERITY_CHOICES)
    detected_at    = models.DateTimeField()
    created_by     = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    created_at     = models.DateTimeField(auto_now_add=True)
```

### Serializer

```python
# apps/flood/serializers.py

class FloodEventInputSerializer(serializers.Serializer):
    region_name    = serializers.CharField(max_length=200)
    severity_level = serializers.ChoiceField(choices=['low', 'medium', 'high'])
    detected_at    = serializers.DateTimeField()


class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    region_name    = serializers.CharField()
    severity_level = serializers.CharField()
    detected_at    = serializers.DateTimeField()
    created_by     = serializers.EmailField(source='created_by.email')
```

### Service

```python
# apps/flood/services.py

@transaction.atomic
def flood_event_create(
    *,
    region_name: str,
    severity_level: str,
    detected_at,
    created_by,
) -> FloodEvent:
    event = FloodEvent(
        region_name=region_name,
        severity_level=severity_level,
        detected_at=detected_at,
        created_by=created_by,
    )
    event.full_clean()
    event.save()

    transaction.on_commit(
        lambda: notify_emergency_services_task.delay(event.id)
    )

    return event
```

### View

```python
# apps/flood/views.py

class FloodEventCreateAPIView(APIView):

    def post(self, request):
        serializer = FloodEventInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        event = flood_event_create(
            **serializer.validated_data,
            created_by=request.user,
        )

        output = FloodEventOutputSerializer(event)
        return Response(output.data, status=status.HTTP_201_CREATED)
```

View: 7 lines. All the logic is in the Service. The View does not know what happens inside.

---

## A Service does not know where it is called from

The same function:

```python
# From a REST API View
event = flood_event_create(region_name="Kyiv", severity_level="high", ...)

# From a Celery task
event = flood_event_create(region_name="Lviv", severity_level="medium", ...)

# From a management command
event = flood_event_create(region_name="Odesa", severity_level="low", ...)

# From a test
event = flood_event_create(region_name="Test", severity_level="high", ...)
```

The logic runs the same way regardless of how the call arrived.

---

## Naming Convention

```python
# Creation
user_create(*, email, password) -> User
flood_event_create(*, region_name, severity_level) -> FloodEvent

# Update
user_update(*, user, name) -> User
flood_event_update(*, event, severity_level) -> FloodEvent

# Deletion
user_delete(*, user) -> None
flood_event_delete(*, event) -> None

# Complex workflows
user_complete_onboarding(*, user) -> User
flood_event_mark_processed(*, event) -> FloodEvent
payment_process(*, order, card_token) -> Payment
pipeline_run_dem_validation(*, dem_file) -> ValidationResult
```

Name = **action + what happens**. Not `process()`, not `handle()`, not `do_stuff()`.

---

## What a Service must NOT do

| Action | Why not |
|-----|---------|
| `return Response(...)` | A Service does not know HTTP |
| `import request` or `self.request` | A Service does not know about Views |
| Direct SELECTs without a Selector | Reading is the Selector's responsibility |
| Render templates | That is the Template / View level |
| Contain business logic in a Celery task | A task is transport, not domain |
| Raise HTTP status codes | The domain raises `ValidationError`, not `400` |

---

## Quick cheat sheet

```python
# services.py — template

from django.db import transaction
from apps.<app>.models import <Model>


def <model>_create(
    *,
    <field_1>: <type>,
    <field_2>: <type>,
) -> <Model>:
    obj = <Model>(
        <field_1>=<field_1>,
        <field_2>=<field_2>,
    )
    obj.full_clean()
    obj.save()
    return obj


@transaction.atomic
def <model>_create_with_side_effect(
    *,
    <field>: <type>,
) -> <Model>:
    obj = <Model>(<field>=<field>)
    obj.full_clean()
    obj.save()

    transaction.on_commit(
        lambda: some_celery_task.delay(obj.id)
    )

    return obj


def <model>_update(
    *,
    obj: <Model>,
    <field>: <type>,
) -> <Model>:
    obj.<field> = <field>
    obj.full_clean()
    obj.save(update_fields=['<field>'])
    return obj


def <model>_delete(*, obj: <Model>) -> None:
    obj.delete()
```

---

## Connection to the rest of the documentation

| Topic | File |
|------|------|
| Selectors (reading data) | [DJANGO_SELECTORS.md](django_selectors_full.md) |
| Services + Selectors + Serializers (the full picture) | [DJANGO_SERVICES_SELECTORS.md](services_selectors_full.md) |
| ORM: `full_clean`, `save`, transactions | [DJANGO_ORM_DEEP.md](../03_database_and_orm/django_orm_deep_full.md) |
| Views: how to pass data to a Service | [notes_chat_app/README.md](../../README.md) — Step 8 |
