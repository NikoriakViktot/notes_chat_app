# Django Selectors — the data reading layer

> `selectors.py` is a separate file in every Django app
> where all ORM queries for READING data live.
> A selector is a **named, reusable query**.

---

## The problem without Selectors

In any Django project, code like this appears very quickly:

```python
# views.py
Post.objects.filter(is_active=True, published_at__lte=timezone.now())

# tasks.py
Post.objects.filter(is_active=True, published_at__lte=timezone.now())

# admin.py
Post.objects.filter(is_active=True, published_at__lte=timezone.now())

# services.py
Post.objects.filter(is_active=True, published_at__lte=timezone.now())
```

The same query is copied into 20 places.

**What happens next:**
- The business logic changes (a new `is_deleted` field is added) — 20 places need updating
- Each developer writes the query slightly differently — inconsistencies in behavior
- It is unclear where to optimize `select_related` centrally
- The code reads like SQL, not like the business domain

---

## The solution: a Selector

```python
# apps/blog/selectors.py

from django.utils import timezone
from apps.blog.models import Post


def get_published_posts():
    return Post.objects.filter(
        is_active=True,
        published_at__lte=timezone.now()
    )
```

Now everywhere:

```python
# views.py
from apps.blog.selectors import get_published_posts

posts = get_published_posts()

# tasks.py
posts = get_published_posts()

# services.py
posts = get_published_posts()
```

The logic is in one place. A change is made in one place.

---

## What a Selector is architecturally

A selector is an **abstraction over the intent of a query**.

| Level | Responsible for | Example |
|--------|---------------|---------|
| PostgreSQL | Stores data | `SELECT ... WHERE ...` |
| ORM | How to get the data | `Post.objects.filter(...)` |
| **Selector** | **WHAT we want (business language)** | `get_published_posts()` |
| View / Service | Orchestration | `posts = get_published_posts()` |

A selector hides the ORM and returns a **domain name**:

```python
# ORM — technical language
Post.objects.filter(Q(author=user) | Q(is_public=True)).select_related('author')

# Selector — domain language
get_visible_posts_for_user(user=user)
```

---

## CQRS-light: Reads vs Writes

In a Django architecture, the business layer is split into two clear roles:

```
services.py   →   WRITE / State change
selectors.py  →   READ  / State reading
```

This is a simplified version of the **CQRS** (Command Query Responsibility Segregation) pattern:

| | **Services** | **Selectors** |
|-|--------------|---------------|
| Role | Command — changes state | Query — reads state |
| Operations | CREATE, UPDATE, DELETE | SELECT |
| Transactions | `@transaction.atomic` | No |
| Side effects | Yes (email, Celery) | Never |
| Returns | The domain object after changes | A QuerySet or data |

> **The main rule:** A selector **never** changes data.

```python
# BAD — a selector that mutates data
def get_or_create_user(email):
    user, _ = User.objects.get_or_create(email=email)  # CREATE — this is not a selector
    return user

# GOOD — split it
# selectors.py
def get_user_by_email(*, email: str):
    return User.objects.filter(email=email).first()

# services.py
def user_create(*, email: str, name: str) -> User:
    user = User(email=email, name=name)
    user.full_clean()
    user.save()
    return user
```

---

## Anatomy of a Selector

### Basic rules (the same as for Services)

- Lives in `<app_name>/selectors.py`
- A stateless Python function (not a class)
- Keyword-only arguments (`*`) — protection against argument-order mistakes
- Strict type annotations
- Knows nothing about HTTP, does not import DRF

```python
# apps/flood/selectors.py

from django.db.models import QuerySet, Count
from apps.flood.models import FloodEvent, Region


def flood_event_get_by_id(*, event_id: int) -> FloodEvent:
    """Returns one object or raises DoesNotExist."""
    return FloodEvent.objects.get(id=event_id)


def flood_events_get_for_region(*, region_id: int) -> QuerySet:
    """All events for a region with optimized JOINs."""
    return (
        FloodEvent.objects
        .filter(region_id=region_id)
        .select_related('region', 'created_by')
        .prefetch_related('satellite_images')
        .order_by('-detected_at')
    )


def flood_events_get_visible_for(*, user) -> QuerySet:
    """
    Hides complex Q logic behind a domain name.
    The caller does not know the filtering details.
    """
    from django.db.models import Q
    return (
        FloodEvent.objects
        .filter(Q(created_by=user) | Q(is_public=True))
        .select_related('region')
        .annotate(image_count=Count('satellite_images'))
        .order_by('-detected_at')
    )
```

---

## Centralizing ORM optimizations

The main technical advantage of Selectors is that **N+1 is solved in one place**.

### The problem: a query in a model property

```python
# BAD — a hidden query on every access
class FloodEvent(models.Model):

    @property
    def region_name(self):
        return self.region.display_name   # SELECT every time

# In a template or serializer:
for event in events:           # 1 query
    print(event.region_name)   # + N queries → N+1 disaster
```

### The solution: select_related in a Selector

```python
# GOOD — one JOIN at the SQL level
def flood_events_get_list() -> QuerySet:
    return (
        FloodEvent.objects
        .all()
        .select_related('region')          # JOIN for ForeignKey
        .prefetch_related('tags')          # batched SELECT for M2M
        .annotate(
            comment_count=Count('comments')  # computed in SQL, not Python
        )
    )

# Now in the loop — ZERO additional queries
for event in flood_events_get_list():
    print(event.region.display_name)   # already in memory
    print(event.comment_count)         # already there from annotate
```

### When to use what

| ORM method | When | Relationship type |
|-----------|------|-------------|
| `select_related()` | ForeignKey, OneToOne | JOIN at the SQL level |
| `prefetch_related()` | ManyToMany, reverse FK | Separate SELECT + Python join |
| `annotate()` | Aggregates, computations | SQL GROUP BY / subquery |
| `only(*fields)` | Huge models, 2-3 fields needed | Partial SELECT |
| `defer(*fields)` | Exclude heavy fields (e.g. TextField) | Partial SELECT |

---

## QuerySet vs evaluated result

A selector can return two kinds of things:

### QuerySet (a query not yet executed)

```python
def flood_events_get_list() -> QuerySet:
    return FloodEvent.objects.filter(is_active=True).select_related('region')
```

**When:** The view can safely add pagination, `django_filters`, `.count()`.

```python
# View
queryset = flood_events_get_list()

# DRF pagination — safe, the QuerySet has not been executed yet
page = self.paginate_queryset(queryset)
```

### Evaluated list / dict

```python
def flood_events_get_summary(*, user) -> list[dict]:
    """A complex structure — built in Python after a single SQL query."""
    events = (
        FloodEvent.objects
        .filter(created_by=user)
        .select_related('region')
        .values('id', 'region__display_name', 'severity_level', 'detected_at')
    )

    return [
        {
            'id': e['id'],
            'region': e['region__display_name'],
            'severity': e['severity_level'],
            'detected_at': e['detected_at'].isoformat(),
        }
        for e in events
    ]
```

**When:** Complex data transformation, an in-memory cache, working around the limitations of nested serializers.

---

## Selector + django-filter (no ORM leaking into the View)

```python
# apps/flood/filters.py
import django_filters
from apps.flood.models import FloodEvent

class FloodEventFilter(django_filters.FilterSet):
    severity  = django_filters.ChoiceFilter(choices=FloodEvent.SEVERITY_CHOICES)
    after     = django_filters.DateTimeFilter(field_name='detected_at', lookup_expr='gte')

    class Meta:
        model  = FloodEvent
        fields = ['severity', 'after']
```

```python
# apps/flood/views.py
class FloodEventListAPIView(ListAPIView):

    def get_queryset(self):
        qs = flood_events_get_visible_for(user=self.request.user)  # selector
        return FloodEventFilter(self.request.GET, queryset=qs).qs  # filter
```

The view does not know SQL. The selector does not know about query params. The filter does not know the business rules.

---

## The full workflow

```
HTTP GET /api/flood/events/?severity=high
        │
        ▼
┌──────────────────────────────────────┐
│  View                                │
│  Calls the selector                  │
│  Passes the QuerySet to the filter   │
│  Paginates the result                │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  Selector                            │
│  flood_events_get_visible_for(user)  │
│  select_related('region')            │
│  annotate(image_count=Count(...))    │
│  Returns a QuerySet                  │
└──────────────┬───────────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│  ORM                                 │
│  Compiles into optimal SQL           │
│  SELECT flood_event.*, region.*,     │
│         COUNT(images.id)             │
│  FROM flood_event                    │
│  JOIN region ON ...                  │
│  WHERE (created_by=$1 OR is_public)  │
│  AND severity='high'                 │
└──────────────┬───────────────────────┘
               │
               ▼
         PostgreSQL
               │
               ▼
    One optimized query
```

---

## Naming Convention

Selectors should be named so that they read like business phrases:

```python
# Get one object
user_get_by_id(*, user_id: int) -> User
flood_event_get_by_id(*, event_id: int) -> FloodEvent

# Get a list
flood_events_get_list() -> QuerySet
flood_events_get_visible_for(*, user) -> QuerySet
users_get_active() -> QuerySet

# Get with a filter
papers_get_unvalidated() -> QuerySet
jobs_get_failed_since(*, since: datetime) -> QuerySet
dem_candidates_get_best_for_region(*, region_id: int) -> QuerySet
```

The name says **WHAT** is needed. The ORM inside says **HOW** to get it.

---

## What a Selector must NOT do

| Action | Why not |
|-----|---------|
| `obj.save()` | This is a mutation — the Service's job |
| `obj.delete()` | This is a mutation — the Service's job |
| `get_or_create()` | Mutates data — this is a Service |
| Open `@transaction.atomic` | Only the Service is responsible for transactions |
| Send email or start Celery | Side effects — Service only |
| Know about `request` or `Response` | A selector does not know HTTP |

---

## Quick cheat sheet

```python
# selectors.py — template

from apps.<app>.models import <Model>


def <model>_get_by_id(*, <model>_id: int) -> <Model>:
    return <Model>.objects.get(id=<model>_id)


def <model>s_get_list() -> QuerySet:
    return (
        <Model>.objects
        .all()
        .select_related('<fk_field>')
        .prefetch_related('<m2m_field>')
        .order_by('-created_at')
    )


def <model>s_get_for_<condition>(*, <param>) -> QuerySet:
    return (
        <Model>.objects
        .filter(<field>=<param>)
        .select_related('<fk_field>')
    )
```

---

## Connection to the rest of the documentation

| Topic | File |
|------|------|
| Services (business logic, mutations, transactions) | [DJANGO_SERVICES.md](django_services_full.md) |
| Services + Selectors + Serializers (the full picture) | [DJANGO_SERVICES_SELECTORS.md](services_selectors_full.md) |
| ORM: QuerySet API, N+1, `select_related` | [DJANGO_ORM_DEEP.md](../03_database_and_orm/django_orm_deep_full.md) |
| Views: how to call a Selector from a View | [notes_chat_app/README.md](../../README.md) — Step 8 |
