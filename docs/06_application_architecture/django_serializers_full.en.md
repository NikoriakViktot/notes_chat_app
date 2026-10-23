# Django Serializers — Transport Layer

> `serializers.py` is the boundary between HTTP and the domain.
> A serializer knows no business logic. It only:
> accepts raw HTTP data → validates it → returns `validated_data`,
> or accepts a domain object → formats it → returns JSON.

---

## What a Serializer is architecturally

```
HTTP Request
    │  {"region_name": "Kyiv", "severity": "high"}
    ▼
InputSerializer.is_valid()
    │  validated_data = {"region_name": "Kyiv", "severity": "high"}
    ▼
Service
    │  FloodEvent object
    ▼
OutputSerializer(event)
    │  {"id": 1, "region_name": "Kyiv", ...}
    ▼
HTTP Response
```

A serializer is a **guard at the entrance and a formatter at the exit**.

| Class | Direction | Role |
|------|--------|------|
| `InputSerializer` | HTTP → Domain | Validation of types, formats, cross-field rules |
| `OutputSerializer` | Domain → HTTP | Response formatting, field selection |

---

## The problem: the ModelSerializer anti-pattern

`ModelSerializer` is a convenient class that automatically generates fields from a model.

```python
# BAD — ModelSerializer is tightly coupled to the DB schema
class FloodEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = FloodEvent
        fields = '__all__'
```

**What breaks:**
- A model change → an automatic API change (unexpected for clients)
- One serializer for reading AND writing → an implicit contract
- Business fields (for example, `created_by` as a ForeignKey) leak into the response as an ID
- Logic in `serializer.save()` — business logic in the transport layer

### When ModelSerializer is acceptable

`ModelSerializer` is fine for simple CRUD endpoints where the model and the API match. For complex workflows — explicit `InputSerializer` and `OutputSerializer`.

---

## InputSerializer — validating input data

### The basis: `serializers.Serializer`

```python
# apps/flood/serializers.py

class FloodEventInputSerializer(serializers.Serializer):
    region_name    = serializers.CharField(max_length=200)
    severity_level = serializers.ChoiceField(choices=['low', 'medium', 'high'])
    detected_at    = serializers.DateTimeField()
```

The base `Serializer` (not `ModelSerializer`) gives an explicit contract:
- Fields do not depend on the DB schema
- A model change does not change the API automatically
- It is immediately clear what is expected from the client

### Usage in a View

```python
# apps/flood/views.py

class FloodEventCreateAPIView(APIView):

    def post(self, request):
        serializer = FloodEventInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        # validated_data — guaranteed clean, checked data
        event = flood_event_create(**serializer.validated_data, created_by=request.user)

        output = FloodEventOutputSerializer(event)
        return Response(output.data, status=status.HTTP_201_CREATED)
```

`raise_exception=True` — if validation fails, DRF automatically returns HTTP 400 with a description of the errors. No extra `if not serializer.is_valid(): return Response(...)`.

---

## OutputSerializer — formatting the response

```python
class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    region_name    = serializers.CharField()
    severity_level = serializers.CharField()
    detected_at    = serializers.DateTimeField()
    created_by     = serializers.EmailField(source='created_by.email')
    created_at     = serializers.DateTimeField()
```

`source='created_by.email'` — instead of returning `created_by: 42` (an ID), we return the email. The client gets what it needs, not internal DB details.

### A list of objects

```python
# many=True — serializing a QuerySet or a list
events = flood_events_get_list()
output = FloodEventOutputSerializer(events, many=True)
return Response(output.data)
```

### Nested objects

```python
class RegionOutputSerializer(serializers.Serializer):
    id           = serializers.IntegerField()
    display_name = serializers.CharField()


class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    region         = RegionOutputSerializer()   # nested object
    severity_level = serializers.CharField()
```

> If nested serializers trigger N+1 queries, switch to a pure Python function (see the section below).

---

## Serializer fields — reference

### Basic types

| Field | Python type | Example |
|------|-----------|---------|
| `CharField` | `str` | names, descriptions |
| `IntegerField` | `int` | IDs, counts |
| `FloatField` | `float` | coordinates, numbers |
| `BooleanField` | `bool` | flags |
| `DateTimeField` | `datetime` | timestamps |
| `DateField` | `date` | dates without time |
| `EmailField` | `str` (with email validation) | addresses |
| `URLField` | `str` (with URL validation) | links |
| `UUIDField` | `UUID` | unique identifiers |

### Choosing from a list

```python
severity = serializers.ChoiceField(choices=['low', 'medium', 'high'])

# Or via constants from the model
severity = serializers.ChoiceField(choices=FloodEvent.SEVERITY_CHOICES)
```

### Optional and default fields

```python
# The field is not required — if not provided, it will be None
description = serializers.CharField(required=False, allow_null=True)

# The field is not required — if not provided, it gets the default value
page_size = serializers.IntegerField(required=False, default=20)
```

### Read-only / write-only

```python
# read_only — the field is in the response but is not accepted in the request
id         = serializers.IntegerField(read_only=True)
created_at = serializers.DateTimeField(read_only=True)

# write_only — the field is accepted in the request but not returned in the response
password   = serializers.CharField(write_only=True)
```

### SerializerMethodField — computed fields

```python
class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    severity_label = serializers.SerializerMethodField()

    def get_severity_label(self, obj) -> str:
        labels = {'low': 'Низький', 'medium': 'Середній', 'high': 'Високий'}
        return labels.get(obj.severity_level, obj.severity_level)
```

---

## validate() — cross-field validation

`validate(self, data)` runs after all individual fields have been checked. It is the place for:
- validating dependencies between fields
- auto-generating values (slug, token)
- transforming data before `validated_data`

```python
class EventRangeInputSerializer(serializers.Serializer):
    start_date = serializers.DateField()
    end_date   = serializers.DateField()

    def validate(self, data: dict) -> dict:
        if data['end_date'] < data['start_date']:
            raise serializers.ValidationError(
                "end_date не може бути раніше ніж start_date"
            )
        return data
```

### Auto-generating a field in validate()

```python
class FloodEventInputSerializer(serializers.Serializer):
    region_name = serializers.CharField()
    slug        = serializers.SlugField(read_only=True)  # generated by the server

    def validate(self, data: dict) -> dict:
        data['slug'] = slugify(data['region_name'])
        return data
```

> `read_only=True` is mandatory — otherwise DRF will require `slug` in the request and fail before `validate()` is called.

### validate_`<field>`() — validating a single field

```python
class UserRegisterInputSerializer(serializers.Serializer):
    email    = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email вже зареєстрований")
        return value.lower()   # transformation — normalize to lowercase

    def validate_password(self, value: str) -> str:
        if len(value) < 8:
            raise serializers.ValidationError("Мінімум 8 символів")
        return value
```

---

## Validation execution order

```
1. Parsing the request body (JSON → Python dict)
        │
        ▼
2. Checking each field individually
   CharField(max_length=200)? → checks
   ChoiceField(choices=[...])? → checks
        │
        ▼
3. validate_<field>() for each field
   validate_email() → checks uniqueness
        │
        ▼
4. validate() → cross-field validation
   end_date > start_date?
        │
        ▼
5. validated_data — guaranteed clean data
        │
        ▼
6. The View passes validated_data to the Service
```

If any step raises `ValidationError`, the following steps are not executed and the client receives HTTP 400.

---

## Mapping domain errors to HTTP

The Service calls `full_clean()` and raises `django.core.exceptions.ValidationError`.
DRF expects `rest_framework.exceptions.ValidationError`.

Without configuration, Django will return a 500 HTML page instead of a JSON 400.

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

After this: `full_clean()` in any Service → automatically a JSON 400.

---

## Complex serialization — a pure Python function

When an OutputSerializer triggers N+1 or the response structure is too complex:

```python
# apps/flood/serializers.py  (or selectors.py)

def flood_feed_serialize(events) -> list[dict]:
    """
    Instead of a nested OutputSerializer — a Python function
    after a single optimized SQL query.
    """
    region_cache: dict[int, str] = {}

    result = []
    for event in events:
        region_id = event.region_id
        if region_id not in region_cache:
            region_cache[region_id] = event.region.display_name  # already in select_related

        result.append({
            'id': event.id,
            'region': region_cache[region_id],
            'severity': event.severity_level,
            'detected_at': event.detected_at.isoformat(),
            'image_count': event.image_count,  # from annotate()
        })

    return result
```

```python
# views.py
events = flood_events_get_list()   # selector: select_related + annotate
data   = flood_feed_serialize(events)
return Response(data)
```

Advantage: full control over the SQL footprint. The selector runs one optimized query, Python builds the structure — no hidden queries from nested serializers.

---

## Full example: a CRUD endpoint

```python
# apps/flood/serializers.py

class FloodEventInputSerializer(serializers.Serializer):
    region_name    = serializers.CharField(max_length=200)
    severity_level = serializers.ChoiceField(choices=['low', 'medium', 'high'])
    detected_at    = serializers.DateTimeField()

    def validate_region_name(self, value: str) -> str:
        return value.strip().title()


class FloodEventUpdateInputSerializer(serializers.Serializer):
    severity_level = serializers.ChoiceField(choices=['low', 'medium', 'high'])
    detected_at    = serializers.DateTimeField(required=False)


class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    region_name    = serializers.CharField()
    severity_level = serializers.CharField()
    detected_at    = serializers.DateTimeField()
    created_by     = serializers.EmailField(source='created_by.email')
    created_at     = serializers.DateTimeField()
```

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

        return Response(
            FloodEventOutputSerializer(event).data,
            status=status.HTTP_201_CREATED,
        )


class FloodEventDetailAPIView(APIView):

    def get(self, request, event_id: int):
        event = flood_event_get_by_id(event_id=event_id)
        return Response(FloodEventOutputSerializer(event).data)

    def patch(self, request, event_id: int):
        event = flood_event_get_by_id(event_id=event_id)

        serializer = FloodEventUpdateInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        event = flood_event_update(event=event, **serializer.validated_data)

        return Response(FloodEventOutputSerializer(event).data)
```

---

## Common mistakes

### Logic in `save()`

```python
# BAD — business logic in the transport layer
class FloodEventSerializer(serializers.ModelSerializer):
    def save(self):
        instance = super().save()
        send_notification_email(instance)   # a side effect in the serializer
        return instance
```

```python
# GOOD — logic in the Service
event = flood_event_create(**serializer.validated_data)
# The Service is responsible for the notification via on_commit + Celery
```

### A direct `queryset` in a serializer

```python
# BAD — the serializer runs DB queries
class FloodEventOutputSerializer(serializers.Serializer):
    related_events = serializers.SerializerMethodField()

    def get_related_events(self, obj):
        return FloodEvent.objects.filter(region=obj.region).count()  # N+1
```

```python
# GOOD — annotate in the Selector, pass it to the serializer
class FloodEventOutputSerializer(serializers.Serializer):
    related_count = serializers.IntegerField()  # from annotate() in the selector
```

### One serializer for writing and reading

```python
# BAD — an unclear contract
class FloodEventSerializer(serializers.ModelSerializer):
    class Meta:
        model = FloodEvent
        fields = ['id', 'region_name', 'severity_level', 'created_by']
        # id is read-only, created_by is read-only,
        # but that is not obvious from the code
```

```python
# GOOD — explicit separate classes
class FloodEventInputSerializer(serializers.Serializer):
    region_name    = serializers.CharField()
    severity_level = serializers.ChoiceField(choices=[...])

class FloodEventOutputSerializer(serializers.Serializer):
    id             = serializers.IntegerField()
    region_name    = serializers.CharField()
    severity_level = serializers.CharField()
    created_by     = serializers.EmailField(source='created_by.email')
```

---

## Table: what a Serializer must not do

| Action | Why not |
|-----|---------|
| Save to the DB (`save()` with logic) | That is the Service |
| Run ORM queries in a `SerializerMethodField` | N+1, that is the Selector |
| Contain business rules | That is the Service or `full_clean()` on the model |
| Know about `transaction.atomic` | That is the Service |
| Know about Celery tasks | That is the Service |
| Return a `Response` | That is the View |

---

## Quick cheat sheet

```python
# serializers.py — template

class <Model>InputSerializer(serializers.Serializer):
    """Input data contract. Independent of the model."""
    <field_1> = serializers.<FieldType>(...)
    <field_2> = serializers.<FieldType>(...)

    def validate_<field_1>(self, value):
        # Validation of a single field
        return value

    def validate(self, data: dict) -> dict:
        # Cross-field validation or transformation
        return data


class <Model>OutputSerializer(serializers.Serializer):
    """Output data contract. What the client sees in the response."""
    id        = serializers.IntegerField()
    <field_1> = serializers.<FieldType>()
    <computed> = serializers.SerializerMethodField()

    def get_<computed>(self, obj):
        return ...
```

---

## Connection to the rest of the documentation

| Topic | File |
|------|------|
| Services (what to do with `validated_data`) | [DJANGO_SERVICES.md](django_services_full.md) |
| Selectors (how to prepare data for the OutputSerializer) | [DJANGO_SELECTORS.md](django_selectors_full.md) |
| Services + Selectors + Serializers (the full picture) | [DJANGO_SERVICES_SELECTORS.md](services_selectors_full.md) |
| Views: how to put it all together | [Django_Views.md](../02_django_core/views_full.md) |
