# Django Admin + Unfold — Internal Tools Architecture

> Django Admin is the built-in admin interface for managing models.
> Unfold is a modern UI layer on top of it, built with Tailwind CSS.
> This file covers the standard Django admin and the complete Unfold system,
> from basic setup to enterprise architecture.

---

## Contents


- [0. What Django Admin is and why Unfold](#0-what-django-admin-is-and-why-unfold)
- [1. AdminSite — the interface coordinator](#1-adminsite--the-interface-coordinator)
- [2. ModelAdmin — the CRUD generator](#2-modeladmin--the-crud-generator)
- [3. Admin Request Lifecycle — from HTTP to the DB](#3-admin-request-lifecycle)
- [4. ChangeList — the list engine](#4-changelist--the-list-engine)
- [5. Query Architecture — query optimization](#5-query-architecture)
- [6. Admin Rendering Pipeline — templates and TemplateResponse](#6-admin-rendering-pipeline)
- [7. Unfold — installation and basic configuration](#7-unfold--installation-and-basic-configuration)
- [8. Sidebar + Navigation Architecture](#8-sidebar--navigation-architecture)
- [9. Dashboard — layouts and DASHBOARD_CALLBACK](#9-dashboard--layouts-and-dashboard_callback)
- [10. Widget Systems — Card, Chart, Tracker, Cohort](#10-widget-systems)
- [11. Information Hierarchy — Fieldset tabs, Conditional fields](#11-information-hierarchy)
- [12. Enterprise Patterns — parallel UnfoldAdminSite, InfinitePaginator](#12-enterprise-patterns)
- [13. Admin Anti-Patterns](#13-admin-anti-patterns)
- [14. Self-check questions](#14-self-check-questions)
- [15. Advanced Filtering — AutocompleteSelectFilter, RangeDateTimeFilter](#15-advanced-filtering--unfold-filters)
- [16. Bulk Actions and Dialog Actions — BaseDialogForm](#16-bulk-actions-and-dialog-actions)
- [17. Component Classes — @register_component](#17-component-classes--register_component)
- [18. Custom Pages — UnfoldModelAdminViewMixin](#18-custom-pages--unfoldmodeladminviewmixin)
- [19. Advanced Widgets — WysiwygWidget, ArrayWidget](#19-advanced-widgets)
- [20. Performance and Caching — cached.Loader, full-text search, Redis](#20-performance-and-caching)
- [21. Datasets — related records in the ChangeForm](#21-datasets--related-records-in-the-changeform)
- [22. Production Checklist](#22-production-checklist)

---
- **🧠 Mental model:** Django Admin is a LEGO kit for internal tools. Every model (Note, Category, User) is a set of bricks. Django automatically builds a complete CRUD interface from them: a list, an add form, an edit form, deletion. Unfold is a new set of "LEGO" on top of the old one: the same bricks, but a modern design and new components.
- **📚 Why it exists:** Before Django Admin, every project had to build its admin panel by itself: HTML forms, validation, access permissions, pagination. Django Admin solved this problem once and for all — automatic CRUD for any registered model, with permissions, auditing, and search out of the box. Unfold solved the problem of the standard admin's outdated look (Django's own CSS, not Bootstrap) — without changing business logic.
- **🌐 What happens under the hood:** When Django starts, the `apps.py` of every installed app is executed. `admin.autodiscover()` finds and loads `admin.py` in every app. Each `admin.site.register(Model, ModelAdmin)` registers the model in the global `AdminSite` singleton. On a request to `/admin/`, Django calls `AdminSite.urls`, which dynamically generates URL routes for all registered models.
- **❌ Common beginner mistake:** Thinking that Django Admin is for end users. The admin is intended EXCLUSIVELY for the internal team: administrators, editors, support. External users should get a separate interface built on regular Django Views + Bootstrap. Using the admin as a "frontend" is an anti-pattern.
---

## Orientation: How to Read This Document

Before diving into the sections, understand the overall architectural picture:

```
The whole Django Admin is three layers stacked on top of each other:

┌─────────────────────────────────────────────────────┐
│                 Your code                           │
│   ModelAdmin, actions, inlines, custom views        │
│   (§2, §4, §11, §16–18)                             │
├─────────────────────────────────────────────────────┤
│               Unfold Layer                          │
│   Tailwind UI, Dashboard, Sidebar, Components       │
│   (§7–12, §15–21)                                   │
├─────────────────────────────────────────────────────┤
│           django.contrib.admin                      │
│   AdminSite, ModelAdmin base, ChangeList, ORM       │
│   (§1–6)                                            │
├─────────────────────────────────────────────────────┤
│           Django Core                               │
│   ORM, Template Engine, Middleware, Auth            │
└─────────────────────────────────────────────────────┘
```

**Reading order for beginners:**

1. [§0 → the big picture, why Admin at all](#0-what-django-admin-is-and-why-unfold)
2. [§3 → Request Lifecycle (you understand how Django handles an admin request)](#3-admin-request-lifecycle)
3. [§2 → ModelAdmin (the main tool, 80% of your time is here)](#2-modeladmin--the-crud-generator)
4. [§5 → Query Architecture (N+1 is the most common problem)](#5-query-architecture)
5. [§7 → Unfold installation (after understanding the basics)](#7-unfold--installation-and-basic-configuration)
6. [§9 → Dashboard (the first "wow" feature)](#9-dashboard--layouts-and-dashboard_callback)
7. [§13 → Anti-Patterns (read before writing production code)](#13-admin-anti-patterns)
8. [§22 → Checklist (before deployment)](#22-production-checklist)

---

## §0. What Django Admin Is and Why Unfold

### Django Admin — Built-in CRUD

Django automatically generates a complete admin interface for every registered model:

```
URL /admin/  →  List of apps + models
              →  List of records (ChangeList)
              →  Edit form (ChangeForm)
              →  Add form
              →  Deletion with confirmation
```

```python
# notes_app/admin.py — minimal registration
from django.contrib import admin
from .models import Note

admin.site.register(Note)
# → /admin/notes_app/note/          list of notes
# → /admin/notes_app/note/add/      new note
# → /admin/notes_app/note/42/change/ editing
# → /admin/notes_app/note/42/delete/ deletion
```

### The Problem with the Standard Admin

```
Standard Django Admin            Unfold Admin
─────────────────────────        ─────────────
Django admin's own basic CSS →   Tailwind CSS with a dark theme
Flat list of models          →   Sidebar with hierarchy and icons
No dashboard                 →   Custom page with Chart.js
No command palette           →   Global search (Ctrl+K)
Simple text filters          →   Dropdown + date range filters
No WYSIWYG                   →   TipTap / CKEditor 5 integration
No conditional fields        →   Alpine.js conditional fields
```

### Unfold's Key Philosophy

Unfold **does not replace** `django.contrib.admin` — it extends it.
All standard APIs (`ModelAdmin`, `list_display`, `inlines`) work unchanged.
Unfold adds a modern UI on top of the existing architecture.

```
django.contrib.admin  (architecture, ORM, permissions)
        ↑
    Unfold           (Tailwind UI, components, dashboard)
        ↑
  Your ModelAdmin   (business logic, customization)
```

---

---
- **🧠 Mental model:** `AdminSite` is the "head office" of your admin panel. All models "register" in it as "departments". It controls URL routing (which URLs are available), branding (name, logo), and access permissions (who can log in). No `AdminSite` — no admin. A single project can have several `AdminSite` instances — for example, one for the operations team and a separate one for analysts.
- **📚 Why it exists:** `AdminSite` is a Singleton (a single instance). Django creates `admin.site` automatically at startup. You don't need to create it — only configure it. But if you need isolation (different teams see different models), you can create additional `AdminSite` instances. This is an enterprise pattern for large teams.
- **🌐 What happens under the hood:** `admin.site.register(Note)` adds the `NoteAdmin` class to the internal dictionary `_registry: {Note: NoteAdmin}`. When Django handles the request `/admin/notes_app/note/`, it looks up Note in `_registry`, gets `NoteAdmin`, and delegates the handling to it. `each_context()` is called on EVERY admin request and adds global variables (site name, permissions, messages) to the template context.
- **❌ Common beginner mistake:** Trying to change `site_header` via the `UNFOLD` settings and not seeing any changes — because the `unfold` module is not first in `INSTALLED_APPS`. Or registering a model twice: once via `admin.site.register()` and again via `@admin.register()` — this raises an `AlreadyRegistered` exception.
---

## §1. AdminSite — the Interface Coordinator

### What AdminSite Is

`AdminSite` is a singleton that manages:
- Model registration (`register()`)
- URL routing (`/admin/*`)
- Global branding (`site_header`, `site_title`)
- Template context (`each_context()`)

```python
# Django automatically creates a global instance
from django.contrib import admin

admin.site.site_header = 'Bootstrap Notes Admin'
admin.site.site_title = 'Notes Portal'
admin.site.index_title = 'Notes management'
```

### Multiple AdminSites for Different Roles

```python
# notes_app/admin_sites.py

from django.contrib.admin import AdminSite

class OperationsAdminSite(AdminSite):
    """Admin panel for the operations team."""
    site_header = 'Operations Panel'
    site_title = 'Ops'
    index_title = 'Operations dashboard'

class AnalyticsAdminSite(AdminSite):
    """Read-only analytics panel."""
    site_header = 'Analytics'
    site_title = 'Analytics'

    def has_permission(self, request):
        # Staff only, but without the is_superuser requirement
        return request.user.is_active and request.user.is_staff


operations_admin = OperationsAdminSite(name='operations')
analytics_admin = AnalyticsAdminSite(name='analytics')
```

```python
# urls.py
from notes_app.admin_sites import operations_admin, analytics_admin

urlpatterns = [
    path('admin/', admin.site.urls),               # standard
    path('ops/', operations_admin.urls),            # operations
    path('analytics/', analytics_admin.urls),       # analytics
]
```

```python
# notes_app/admin.py — registration on multiple sites
from notes_app.admin_sites import operations_admin, analytics_admin

@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'author', 'created_at']

# Additional registration on operations_admin
operations_admin.register(Note, NoteAdmin)
analytics_admin.register(Note, NoteAdmin)
```

### each_context() — Injecting Global Variables

```python
class CustomAdminSite(AdminSite):
    def each_context(self, request):
        context = super().each_context(request)
        # Add global variables for all templates of this site
        context.update({
            'company_name': 'Acme Corp',
            'environment': settings.ENVIRONMENT,
            'unread_alerts': SystemAlert.objects.filter(read=False).count(),
        })
        return context
```

---

---
- **🧠 Mental model:** `ModelAdmin` is a declarative "recipe" for automatic CRUD. Like in a cookbook: you describe WHAT you want (`list_display = ['title', 'author']`), and Django does the cooking itself (generates SQL, HTML, forms, pagination). You don't write any HTML — only Python attributes. The `ModelAdmin` class is a SINGLETON — one instance serves all requests from all users at the same time. This is critical for understanding the anti-patterns.
- **📚 Why it exists:** ModelAdmin separates "what to show" from "how to show it". The model knows about the data (fields, validation, relationships). ModelAdmin knows about the admin UX: which fields go in the list, which filters, which actions. If the admin design changes tomorrow, you edit the ModelAdmin, not the model. If the business logic changes, you edit the model, not the ModelAdmin.
- **🌐 What happens under the hood:** On a request to `/admin/notes_app/note/`, Django: (1) finds `NoteAdmin` in `_registry`, (2) calls `NoteAdmin.changelist_view(request)`, (3) this method calls `get_queryset()`, `get_list_display()`, `get_list_filter()` and builds the context, (4) returns `TemplateResponse('admin/change_list.html', context)`. Every attribute (`list_display`, `search_fields`, and so on) is an "instruction" for the corresponding method.
- **❌ Common beginner mistake:** Mutating class attributes inside methods: `self.readonly_fields.append('title')` changes the field for ALL requests and ALL users at once (because ModelAdmin is a singleton). Always return new lists: `return list(self.readonly_fields) + ['title']`. This mistake is one of the hardest to diagnose (the bug shows up under load or with concurrency).
---

## §2. ModelAdmin — the CRUD Generator

### Declarative Configuration

```python
# notes_app/admin.py
from django.contrib import admin
from django.utils.html import format_html
from .models import Note, Category

@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):

    # ── Record list ──────────────────────────────────────────
    list_display = ['title', 'status_badge', 'author', 'category', 'created_at']
    list_display_links = ['title']      # clickable fields
    list_editable = ['category']        # editing directly in the list
    list_filter = ['status', 'category', 'created_at']
    list_per_page = 25
    list_select_related = ['author', 'category']  # avoiding N+1
    search_fields = ['title', 'body', 'author__username']
    ordering = ['-created_at']
    date_hierarchy = 'created_at'       # navigation by date

    # ── Edit form ────────────────────────────────────────────
    fields = ['title', 'body', 'category', 'status', 'is_public']
    # or fieldsets for grouping:
    fieldsets = [
        ('Main information', {
            'fields': ['title', 'category', 'status'],
        }),
        ('Content', {
            'fields': ['body'],
        }),
        ('Settings', {
            'fields': ['is_public', 'author'],
            'classes': ['collapse'],    # collapsed by default
        }),
    ]
    readonly_fields = ['created_at', 'updated_at', 'slug']
    autocomplete_fields = ['author']    # AJAX search (requires search_fields on UserAdmin)
    raw_id_fields = []

    # ── Actions ──────────────────────────────────────────────
    actions = ['publish_selected', 'archive_selected']

    # ── Inline ───────────────────────────────────────────────
    inlines = []  # added below

    # ── Custom field for list_display ────────────────────────
    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        colors = {
            'draft': '#6c757d',
            'published': '#198754',
            'archived': '#ffc107',
        }
        color = colors.get(obj.status, '#0d6efd')
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:4px;font-size:12px;">{}</span>',
            color,
            obj.get_status_display()
        )

    # ── Actions ──────────────────────────────────────────────
    @admin.action(description='Publish selected')
    def publish_selected(self, request, queryset):
        updated = queryset.update(status='published')
        self.message_user(request, f'Published {updated} notes.')

    @admin.action(description='Archive selected')
    def archive_selected(self, request, queryset):
        updated = queryset.update(status='archived')
        self.message_user(
            request,
            f'Archived {updated} notes.',
            level='warning'
        )
```

### Dynamic Configuration by Overriding Methods

```python
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):

    def get_queryset(self, request):
        """Restrict what is shown — everyone sees only their own notes."""
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(author=request.user)

    def get_readonly_fields(self, request, obj=None):
        """The author field is read-only when editing."""
        if obj:  # existing object
            return list(self.readonly_fields) + ['author']
        return self.readonly_fields

    def get_form(self, request, obj=None, **kwargs):
        """Dynamic form depending on the role."""
        form = super().get_form(request, obj, **kwargs)
        if not request.user.is_superuser:
            # Hide the is_public field for regular admins
            form.base_fields.pop('is_public', None)
        return form

    def save_model(self, request, obj, form, change):
        """Automatically set author on creation."""
        if not change:  # new object
            obj.author = request.user
        super().save_model(request, obj, form, change)

    def has_delete_permission(self, request, obj=None):
        """Deletion for superusers only."""
        return request.user.is_superuser
```

### Inline — Nested Forms

```python
class CommentInline(admin.TabularInline):
    model = Comment
    fields = ['author', 'text', 'created_at']
    readonly_fields = ['created_at']
    extra = 1           # number of empty forms
    max_num = 10
    can_delete = True
    show_change_link = True  # link to the full Comment form


class AttachmentInline(admin.StackedInline):
    model = Attachment
    fields = ['file', 'description']
    extra = 0


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    inlines = [CommentInline, AttachmentInline]
```

### Custom URLs in ModelAdmin

```python
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):

    def get_urls(self):
        from django.urls import path
        urls = super().get_urls()
        custom_urls = [
            path(
                '<int:pk>/export/',
                self.admin_site.admin_view(self.export_view),  # ← mandatory
                name='notes_app_note_export',
            ),
        ]
        return custom_urls + urls

    def export_view(self, request, pk):
        note = get_object_or_404(Note, pk=pk)
        # ... generate a PDF or CSV
        response = HttpResponse(content_type='text/plain')
        response['Content-Disposition'] = f'attachment; filename=note_{pk}.txt'
        response.write(note.body)
        return response
```

```html
{# templates/admin/notes_app/note/change_form.html #}
{% extends "admin/change_form.html" %}
{% block object-tools-items %}
{{ block.super }}
<li>
    <a href="{% url 'admin:notes_app_note_export' original.pk %}"
       class="historylink">Export to .txt</a>
</li>
{% endblock %}
```

---

---
- **🧠 Mental model:** The Admin Request Lifecycle is a conveyor belt. Every request to `/admin/note/42/change/` passes through a fixed sequence of "stations": authentication → authorization → fetching the object → permission check → rendering the form (GET) or validation + saving (POST). If any station "refuses", the conveyor stops and returns the appropriate response (403, 404, a form with errors).
- **📚 Why it exists:** The lifecycle clearly separates responsibilities: middleware knows nothing about models, ModelAdmin knows nothing about HTTP details. You can intercept any "station" of the conveyor: `get_form()` to change the form, `save_model()` to change the save logic, `response_change()` to change the redirect. You don't need to rewrite everything — only override the station you need.
- **🌐 What happens under the hood:** `has_change_permission()` runs an SQL query to check permissions (via the `ContentType` framework). `get_form()` dynamically generates a `ModelForm` class on the fly. Model validation (`instance.full_clean()`) already happens in `form.is_valid()`, via `ModelForm._post_clean()`; `save_model()` itself only calls `obj.save()` (an INSERT or UPDATE in the DB). `log_change()` writes a row to the `django_admin_log` table — this is the built-in audit log.
- **❌ Common beginner mistake:** Performing expensive operations (sending email, calling an external API) directly in `save_model()` without try/except. If the email server is unavailable, the admin "crashes" when you try to save. Heavy side effects are better performed in a Celery task launched from `save_model()`.
---

## §3. Admin Request Lifecycle

```
HTTP Request /admin/notes_app/note/42/change/
    │
    ▼
Middleware stack:
    SessionMiddleware    → loads the session
    AuthenticationMiddleware → request.user
    MessageMiddleware   → Django messages framework
    │
    ▼
AdminSite.urls dispatch
    │
    ▼
ModelAdmin.change_view(request, object_id)
    │
    ├─ has_change_permission(request, obj) → 403 if False
    │
    ├─ GET:
    │     get_form() → ModelForm instance
    │     get_readonly_fields()
    │     get_fieldsets()
    │     render TemplateResponse('admin/change_form.html', context)
    │
    └─ POST:
          get_form() with request.POST
          form.is_valid()
              ├─ False: render the form with errors
              └─ True:
                    save_model(request, obj, form, change)
                        → obj.save()
                    save_related(request, form, formsets, change)
                        → save inlines
                    log_change() → LogEntry
                    response_change() → HttpResponseRedirect
```

### Intercepting the Save

```python
def save_model(self, request, obj, form, change):
    """Runs right before obj.save()."""
    if not change:
        obj.created_by = request.user
    obj.last_modified_by = request.user
    super().save_model(request, obj, form, change)

def save_related(self, request, form, formsets, change):
    """Runs after save_model, saves M2M and inlines."""
    super().save_related(request, form, formsets, change)
    # Here obj is already saved and has an ID
    obj = form.instance
    obj.process_tags()  # for example

def response_change(self, request, obj):
    """Control the redirect after a successful save."""
    if '_continue' not in request.POST and '_addanother' not in request.POST:
        # Custom redirect instead of the standard one
        return redirect(reverse('admin:notes_app_note_changelist'))
    return super().response_change(request, obj)
```

---

---
- **🧠 Mental model:** `ChangeList` is the "list manager". If `ModelAdmin` is the recipe, then `ChangeList` is the cook who prepares the list of objects: applies filters, sorting, pagination, search. Django automatically creates a `ChangeList` instance on every list request. If you want to change how the list behaves, create a `ChangeList` subclass and override the methods you need.
- **📚 Why it exists:** `ChangeList` separates the "list display logic" from the "edit form display". This lets you optimize each part independently: a fast list → aggregations and indexes; a slow form → not a problem for the list. `ShowFacets` (Django 5.0+) is a concrete example: it adds a `COUNT(*)` for each filter to show how many records match.
- **🌐 What happens under the hood:** `ChangeList.get_queryset()` builds the queryset step by step: (1) takes the base queryset from `ModelAdmin.get_queryset()`, (2) applies `search_fields` (adds `WHERE title ILIKE '%query%'`), (3) applies `list_filter` (adds `WHERE status='draft'`), (4) applies `date_hierarchy` (WHERE created_at BETWEEN ...), (5) applies sorting (`ORDER BY`), (6) slices for pagination (`LIMIT/OFFSET`). Each step is a separate `.filter()` or `.order_by()` on the QuerySet.
- **❌ Common beginner mistake:** Adding `annotate()` in `ModelAdmin.get_queryset()` but forgetting to add the corresponding field to `list_display` via a custom method with `@admin.display(ordering='annotated_field')`. Without `ordering` on the column, clicking the column header will not sort.
---

## §4. ChangeList — the List Engine

```python
from django.contrib.admin.views.main import ChangeList

class NoteChangeList(ChangeList):
    """Custom ChangeList with an additional aggregation."""

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        # Annotate for use in list_display
        from django.db.models import Count
        return qs.annotate(comments_count=Count('comments'))


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):

    def get_changelist(self, request, **kwargs):
        return NoteChangeList

    @admin.display(description='Comments', ordering='comments_count')
    def comments_count(self, obj):
        return obj.comments_count
```

### Show Facets (Django 5.0+)

```python
from django.contrib.admin import ModelAdmin, ShowFacets

@admin.register(Note)
class NoteAdmin(ModelAdmin):
    list_filter = ['status', 'category']
    show_facets = ShowFacets.ALWAYS
    # → shows "(23)" next to each filter — the number of records
    # ShowFacets.ALLOW (on request) | ShowFacets.ALWAYS | ShowFacets.NEVER
```

---

---
- **🧠 Mental model:** The N+1 problem in the admin is a "snowball effect". For a list page with 25 notes, Django runs 1 query for the notes themselves, and then 25 more queries for the authors and another 25 for the categories — 51 queries in total instead of 1. `list_select_related` "stops the snowball": it fetches everything together with a single `JOIN`. This is the easiest optimization with the biggest effect in Django Admin.
- **📚 Why it exists:** A Django QuerySet is lazy. `note.author` does not run SQL immediately — it waits for the first access. When the template renders `{{ note.author.username }}` for each note, a separate SQL query runs. `select_related` and `prefetch_related` tell the ORM: "do the JOIN in advance, I know I'll be accessing this data".
- **🌐 What happens under the hood:** `list_select_related = ['author', 'category']` → Django adds `SELECT notes.*, users.*, categories.* FROM notes LEFT JOIN users ON ... LEFT JOIN categories ON ...`. One SQL query instead of 1+N. `prefetch_related('tags')` — for M2M you can't JOIN (row duplication), so Django runs two SQL queries: one for the notes, one for the tags, and Python combines them in memory.
- **❌ Common beginner mistake:** `list_select_related = True` (without a list) — Django does a JOIN for ALL ForeignKeys at all depths. For complex models this can be slower than N+1. Always specify explicitly which fields you need: `list_select_related = ['author', 'category']`.
---

## §5. Query Architecture

### N+1 in list_display

```python
# ❌ N+1 — a separate query for author and category for every note
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'author_name', 'category_name']

    def author_name(self, obj):
        return obj.author.username  # SELECT author WHERE id=...

    def category_name(self, obj):
        return obj.category.name    # SELECT category WHERE id=...

# ✅ Fix with list_select_related
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'author_name', 'category_name']
    list_select_related = ['author', 'category']  # JOIN in a single query

    def author_name(self, obj):
        return obj.author.username  # already cached

    def category_name(self, obj):
        return obj.category.name    # already cached
```

### Optimizing search_fields

```python
# ❌ Dangerous search — LIKE on a TEXT field + FK traversal
search_fields = ['body', 'author__profile__bio']
# → WHERE body LIKE '%query%' OR profile.bio LIKE '%query%'
# → Full scan on large tables + JOIN

# ✅ Safe search
search_fields = ['^title', '=author__username']
# ^ — startswith (uses the index!)
# = — exact match
# @ — full-text search (MySQL/PostgreSQL only)
# (no prefix) — icontains (slow, but flexible)
```

### get_search_results() — Custom Search

```python
def get_search_results(self, request, queryset, search_term):
    queryset, use_distinct = super().get_search_results(
        request, queryset, search_term
    )
    # Add search by tags
    if search_term:
        queryset |= self.model.objects.filter(
            tags__name__icontains=search_term
        )
    return queryset, use_distinct
```

### prefetch_related for M2M in list_display

```python
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'tag_list']

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related('tags')

    def tag_list(self, obj):
        return ', '.join(tag.name for tag in obj.tags.all())
    tag_list.short_description = 'Tags'
```

---

---
- **🧠 Mental model:** The Admin Rendering Pipeline is a photo album builder. `ModelAdmin.changelist_view()` collects the "photos" (context: queryset, filters, pagination) but doesn't print them yet. `TemplateResponse` keeps these "photos" in an unrendered state. Middleware can add its own "photos" to the album. Only at the very end does Django "print" the finished book (compile the HTML).
- **📚 Why it exists:** The template hierarchy allows overrides at different levels of detail: want to change something for ALL models — edit `templates/admin/change_list.html`. Want to change it for all models of a specific app — edit `templates/admin/notes_app/change_list.html`. Want to change it only for `Note` — edit `templates/admin/notes_app/note/change_list.html`. Django searches from the most specific to the most general.
- **🌐 What happens under the hood:** When rendering an admin template, the Django Template Engine requests `TemplateEngine.select_template(['admin/notes_app/note/change_list.html', 'admin/notes_app/change_list.html', 'admin/change_list.html'])`. It checks the file system for each option in turn and returns the first one found. This happens on EVERY request (or from the cache with `cached.Loader`).
- **❌ Common beginner mistake:** Creating a `templates/admin/change_list.html` file with your own content and forgetting to write `{% extends "admin/change_list.html" %}` inside it — Django will read YOUR file (the most specific one) and won't find any base structure. The admin will display an empty page or break. ALWAYS `{% extends %}` + `{% block %}` + `{{ block.super }}`.
---

## §6. Admin Rendering Pipeline

### TemplateResponse and Deferred Compilation

```
ModelAdmin.changelist_view()
    │
    └─ return TemplateResponse(
           request,
           'admin/change_list.html',
           context
       )
           │
           │  ← Response middleware can change context_data here
           │
           ▼
    TemplateResponse.render()  (called by Django)
           │
           └─ Template Engine → HTML string → HttpResponse
```

```python
def changelist_view(self, request, extra_context=None):
    # Add custom context
    extra_context = extra_context or {}
    extra_context['total_published'] = Note.objects.filter(
        status='published'
    ).count()
    return super().changelist_view(request, extra_context=extra_context)
```

### Template Hierarchy

```
Django looks for templates in this order:
1. templates/admin/<app>/<model>/change_list.html    (most specific)
2. templates/admin/<app>/change_list.html
3. templates/admin/change_list.html                  (global)
4. django/contrib/admin/templates/admin/change_list.html (built-in)

Example for Note:
templates/
└── admin/
    ├── base_site.html            ← global branding
    ├── change_list.html          ← for all models
    └── notes_app/
        ├── change_list.html      ← for all notes_app models
        └── note/
            ├── change_list.html  ← only for Note
            └── change_form.html
```

```html
{# templates/admin/base_site.html — rebranding the admin #}
{% extends "admin/base.html" %}

{% block branding %}
<h1 id="site-name">
    <a href="{% url 'admin:index' %}">
        🗒️ {{ site_header }}
    </a>
</h1>
{% endblock %}

{% block extrastyle %}
{{ block.super }}
<style>
    #header { background: #1e293b; }
    .module h2 { background: #334155; }
</style>
{% endblock %}
```

---

---
- **🧠 Mental model:** Installing Unfold is a "cosmetic renovation" of Django Admin. You don't knock down walls (you don't change ModelAdmin, the ORM, or access permissions) — you just paint the walls and replace the furniture (CSS/JS templates). All the `ModelAdmin` code you've written keeps working. Unfold simply replaces the templates and styles on top.
- **📚 Why `unfold` is FIRST in `INSTALLED_APPS`:** Django looks for templates in `INSTALLED_APPS` in order. If `unfold` comes after `django.contrib.admin`, Django finds the standard admin templates first and NEVER gets to the Unfold templates. `unfold` MUST be first so that its templates take priority over the standard ones.
- **🌐 What happens under the hood:** Unfold replaces the standard admin templates with its own (in its `templates/admin/` directory). Its templates extend (`{% extends %}`) the original Django admin templates and override the CSS/JS blocks to load Tailwind CSS. `UnfoldModelAdmin` (a subclass of `ModelAdmin`) adds new attributes (`list_fullwidth`, `warn_unsaved_form`, and so on), but doesn't break the standard ones.
- **❌ Common beginner mistake:** Installing Unfold but not switching `ModelAdmin` to `UnfoldModelAdmin`. The base styles will change (because the Unfold templates will load), but the new features (`list_filter_submit`, `warn_unsaved_form`) won't work — they are implemented in `UnfoldModelAdmin`, not in the standard `ModelAdmin`.
---

## §7. Unfold — Installation and Basic Configuration

### Installation

```bash
pip install django-unfold
```

```python
# settings.py — Unfold BEFORE django.contrib.admin
INSTALLED_APPS = [
    'unfold',                       # ← must be first
    'unfold.contrib.filters',       # advanced filters
    'unfold.contrib.forms',         # styled forms
    'unfold.contrib.inlines',       # sortable inlines
    'unfold.contrib.import_export', # if you use django-import-export

    'django.contrib.admin',
    'django.contrib.auth',
    ...
]
```

### Basic UNFOLD Configuration

```python
# settings.py

from django.templatetags.static import static
from django.urls import reverse_lazy
from unfold.enums import BadgeType

UNFOLD = {
    # ── Branding ─────────────────────────────────────────────
    "SITE_TITLE": "Bootstrap Notes",
    "SITE_HEADER": "Notes Admin",
    "SITE_URL": "/",
    "SITE_ICON": lambda request: static("notes_app/img/logo.png"),
    "SITE_LOGO": lambda request: static("notes_app/img/logo-full.png"),
    "SITE_SYMBOL": "notes",             # Material Symbol icon

    # ── Colors (CSS variables) ───────────────────────────────
    "COLORS": {
        "primary": {
            # Define every shade 50…950 — shortened here.
            # Older Unfold versions: an RGB triplet without # or commas; newer ones (Tailwind 4): "oklch(97.7% .014 308.299)".
            "50": "240 249 255",
            "100": "224 242 254",
            "500": "14 165 233",        # → --color-primary-500
            "900": "12 74 110",
        },
    },

    # ── Themes ───────────────────────────────────────────────
    "THEME": "dark",                    # "dark" | "light" | None (auto)

    # ── Dashboard ────────────────────────────────────────────
    "DASHBOARD_CALLBACK": "notes_app.admin_dashboard.dashboard_callback",

    # ── Sidebar navigation ───────────────────────────────────
    "SIDEBAR": {
        "show_search": True,
        "show_all_applications": True,
        "navigation": [
            {
                "title": "Notes",
                "separator": True,
                "collapsible": True,
                "items": [
                    {
                        "title": "All notes",
                        "icon": "description",
                        "link": reverse_lazy("admin:notes_app_note_changelist"),
                        "badge": "notes_app.admin_callbacks.get_draft_count",
                        "badge_type": BadgeType.WARNING,
                    },
                    {
                        "title": "Categories",
                        "icon": "label",
                        "link": reverse_lazy("admin:notes_app_category_changelist"),
                    },
                ],
            },
            {
                "title": "Users",
                "separator": True,
                "items": [
                    {
                        "title": "Users",
                        "icon": "people",
                        "link": reverse_lazy("admin:auth_user_changelist"),
                    },
                ],
            },
        ],
    },

    # ── Global dropdown menu ─────────────────────────────────
    "SITE_DROPDOWN": [
        {
            "icon": "diamond",
            "title": "Production",
            "link": "https://notes.example.com",
        },
        {
            "icon": "code",
            "title": "Staging",
            "link": "https://staging.notes.example.com",
        },
    ],

    # ── Tabs (tabs for forms and lists) ──────────────────────
    "TABS": [
        {
            "models": ["notes_app.note", "notes_app.comment"],
            "items": [
                {
                    "title": "Notes",
                    "icon": "description",
                    "link": reverse_lazy("admin:notes_app_note_changelist"),
                },
                {
                    "title": "Comments",
                    "icon": "comment",
                    "link": reverse_lazy("admin:notes_app_comment_changelist"),
                },
            ],
        },
    ],
}
```

### UnfoldModelAdmin — Unfold's Base Class

```python
# notes_app/admin.py
from unfold.admin import ModelAdmin as UnfoldModelAdmin
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    # All standard Django Admin attributes work
    list_display = ['title', 'status', 'author', 'created_at']
    list_filter = ['status', 'category']
    search_fields = ['^title', '=author__username']

    # Unfold-specific attributes
    list_fullwidth = True           # full-width list
    warn_unsaved_form = True        # warning when leaving without saving
    list_filter_submit = True       # "Apply" button in filters
```

---

---
- **🧠 Mental model:** Sidebar navigation in Unfold is a "restaurant menu" that you write by hand in `settings.py`. The standard Django Admin automatically generates the menu from all registered models (like a "buffet" — everything in a row). Unfold lets you organize navigation by hand: groups, icons, counter badges, collapsible sections. Full control at the cost of more configuration.
- **📚 Why `reverse_lazy` and not `reverse`:** The sidebar configuration in `settings.py` runs when the module is loaded — before Django has fully initialized the URL routes. `reverse('admin:notes_app_note_changelist')` would raise `NoReverseMatch` at that moment. `reverse_lazy` is a "deferred reverse" that runs only on first access (after full initialization).
- **🌐 What happens under the hood:** The sidebar badge callback (`"notes_app.admin_callbacks.get_draft_count"`) is a string path to a Python function. Unfold dynamically imports and calls this function on EVERY sidebar render (on every request). If a badge callback is slow (complex SQL), it will slow down every admin page. Cache the result if possible.
- **❌ Common beginner mistake:** Writing `"link": reverse("admin:notes_app_note_changelist")` (without `_lazy`) in `settings.py` at module level — and getting `ImproperlyConfigured: The included URLconf ... does not appear to have any patterns`. Always use `reverse_lazy` in `settings.py`, the `UNFOLD` dictionary, and anywhere else a URL is generated before Django has fully loaded.
---

## §8. Sidebar + Navigation Architecture

### Dynamic Badge via a Callback

```python
# notes_app/admin_callbacks.py

def get_draft_count(request):
    """Returns the number of drafts for the sidebar badge."""
    from .models import Note
    count = Note.objects.filter(status='draft').count()
    if count == 0:
        return None
    return str(count)
```

```python
# settings.py — UNFOLD → SIDEBAR → items
{
    "title": "Notes",
    "icon": "description",
    "link": reverse_lazy("admin:notes_app_note_changelist"),
    "badge": "notes_app.admin_callbacks.get_draft_count",
    "badge_type": BadgeType.WARNING,   # INFO, SUCCESS, WARNING, DANGER
}
```

### Tabs — Navigation Between Models

```
Changelist tabs:                    Changeform tabs:
┌──────────┬────────────┐          ┌──────────┬──────────┬──────────┐
│ Notes    │ Comments   │          │ Main     │ SEO      │ Media    │
└──────────┴────────────┘          └──────────┴──────────┴──────────┘
[list of notes]                    [edit form with tabs]
```

```python
# settings.py — static tabs
"TABS": [
    {
        "models": ["notes_app.note", "notes_app.comment", "notes_app.category"],
        "items": [
            {
                "title": "Notes",
                "icon": "description",
                "link": reverse_lazy("admin:notes_app_note_changelist"),
            },
            {
                "title": "Comments",
                "icon": "comment",
                "link": reverse_lazy("admin:notes_app_comment_changelist"),
            },
            {
                "title": "Categories",
                "icon": "label",
                "link": reverse_lazy("admin:notes_app_category_changelist"),
            },
        ],
    },
],
```

### Dynamic Tabs (Callback)

```python
# notes_app/admin_callbacks.py

def note_tabs_callback(request):
    """Dynamic tabs depending on the user's permissions."""
    tabs = [
        {
            "title": "My notes",
            "icon": "person",
            "link": f"{reverse('admin:notes_app_note_changelist')}?author={request.user.pk}",
        },
    ]
    if request.user.is_superuser:
        tabs.append({
            "title": "All notes",
            "icon": "groups",
            "link": reverse("admin:notes_app_note_changelist"),
        })
    return tabs
```

```python
# settings.py
"TABS": [
    {
        "models": ["notes_app.note"],
        "items": "notes_app.admin_callbacks.note_tabs_callback",
    },
],
```

---

---
- **🧠 Mental model:** The Django Admin Dashboard is a "blank canvas". The standard admin shows a simple list of apps/models. `DASHBOARD_CALLBACK` is your "artist": it receives an empty context and paints statistics, charts, and cards on it. Then Unfold "hangs" this picture in the `admin/index.html` template.
- **📚 Why a callback instead of a context processor:** A context processor runs for EVERY request to the entire admin. Dashboard data is needed only on the main page. `DASHBOARD_CALLBACK` is called only when `/admin/` is opened — saving resources. It is also an explicit data injection: you know exactly what runs and when.
- **🌐 What happens under the hood:** On a request to `/admin/`, Unfold calls the function from `DASHBOARD_CALLBACK`. This function receives `(request, context)` — where `context` already contains the standard Django admin data. Your function MUTATES the `context` dictionary (`context['stats'] = {...}`) and returns it. Then Unfold renders `admin/index.html` with this enriched context. The `index.html` template in `templates/admin/` replaces the standard one.
- **❌ Common beginner mistake:** Forgetting caching in `DASHBOARD_CALLBACK`. If the function runs 5 complex SQL queries, it will run them on EVERY dashboard load (every time someone opens `/admin/`). Always use `cache.get/set` for aggregated statistics with a TTL of 60–300 seconds.
---

## §9. Dashboard — Layouts and DASHBOARD_CALLBACK

### Custom index.html

```python
# settings.py — point to the callback
"DASHBOARD_CALLBACK": "notes_app.admin_dashboard.dashboard_callback",
```

```python
# notes_app/admin_dashboard.py

import json
from datetime import timedelta

from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone
from .models import Note


def dashboard_callback(request, context):
    """
    Injects data into the admin/index.html template.
    Runs on every dashboard load.
    """
    # Statistics
    context['stats'] = {
        'total_notes': Note.objects.count(),
        'published': Note.objects.filter(status='published').count(),
        'drafts': Note.objects.filter(status='draft').count(),
        'today': Note.objects.filter(
            created_at__date=timezone.now().date()
        ).count(),
    }

    # Chart data (last 14 days)
    two_weeks_ago = timezone.now() - timedelta(days=14)
    daily_counts = (
        Note.objects
        .filter(created_at__gte=two_weeks_ago)
        .annotate(date=TruncDate('created_at'))
        .values('date')
        .annotate(count=Count('id'))
        .order_by('date')
    )

    context['chart_data'] = json.dumps({  # Unfold puts data into data-value="{{ data }}" — a JSON string is required
        'labels': [str(row['date']) for row in daily_counts],
        'datasets': [{
            'label': 'New notes',
            'data': [row['count'] for row in daily_counts],
        }],
    })

    return context
```

### Dashboard Template

```html
{# templates/admin/index.html #}
{% extends "unfold/layouts/base_simple.html" %}
{% load i18n unfold %}

{% block content %}
<div class="flex flex-col gap-6">

    {# ── Stats Cards ──────────────────────────── #}
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {% component "unfold/components/card.html" with title="Total notes" icon="description" footer="All time" %}{% component "unfold/components/title.html" %}{{ stats.total_notes }}{% endcomponent %}{% endcomponent %}

        {% component "unfold/components/card.html" with title="Published" icon="check_circle" class="bg-green-50" %}{% component "unfold/components/title.html" %}{{ stats.published }}{% endcomponent %}{% endcomponent %}

        {% component "unfold/components/card.html" with title="Drafts" icon="edit_note" class="bg-yellow-50" %}{% component "unfold/components/title.html" %}{{ stats.drafts }}{% endcomponent %}{% endcomponent %}

        {% component "unfold/components/card.html" with title="Today" icon="today" %}{% component "unfold/components/title.html" %}{{ stats.today }}{% endcomponent %}{% endcomponent %}
    </div>

    {# ── Chart ────────────────────────────────── #}
    <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
        {% component "unfold/components/chart/line.html" with title="New notes (14 days)" data=chart_data %}{% endcomponent %}

        {# Tracker — activity #}
        {% component "unfold/components/tracker.html" with title="Activity over the year" data=tracker_data %}{% endcomponent %}
    </div>

</div>
{% endblock %}
```

---

---
- **🧠 Mental model:** Unfold Widgets are a "set of premium furniture" for the dashboard. Card is a display case (a single number + context). Chart is a chart (Chart.js under the hood). Tracker is a GitHub-style activity heatmap. Cohort is a retention table (retention analysis). Each widget is an Unfold component that takes data via `with key=value` and renders the corresponding HTML+JS.
- **📚 Why components instead of plain HTML:** The Unfold `{% component %}` tag guarantees a consistent style (dark theme, colors, spacing) without duplicating CSS. You pass data via `with key=value`, and the component itself knows how to display it. When Unfold is updated, the component styles update automatically.
- **🌐 What happens under the hood:** `{% component "unfold/components/chart/line.html" with data=chart_data %}` is a Django `{% include %}` template tag with extra logic. Unfold renders a partial template and passes `chart_data` into it. The Chart template generates `<canvas data-value="{{ data }}">`, so `chart_data` must be a JSON string (`json.dumps(...)`); Unfold's JavaScript reads that attribute and creates `new Chart(...)`. Chart.js (a JavaScript library) picks up the `<canvas>` and draws the chart in the browser.
- **❌ Common beginner mistake:** Passing a Python QuerySet directly into the Chart component's `data`. Unfold expects a JSON string built from a dict with the keys `labels` and `datasets`. The QuerySet must be converted to a dictionary and serialized with `json.dumps()` beforehand in `dashboard_callback`. If you don't, serialization fails with a `TypeError` or the chart is empty.
---

## §10. Widget Systems

### Card — the Basic Container

```python
# parameters of unfold/components/card.html: title, footer, label, icon, class. The number itself is the card's content (children), e.g. a nested title.html
{
    "title": "New sign-ups",
    "footer": "+12% this week",
    "icon": "person_add",
    "label": "+12%",
    "class": "lg:w-1/3",
}
```

```html
{% component "unfold/components/card.html" with title="New sign-ups" icon="person_add" footer="+12% this week" %}{% component "unfold/components/title.html" %}1,284{% endcomponent %}{% endcomponent %}
```

### Chart — Chart.js Integration

```python
import json

# Line chart
chart_data = json.dumps({  # Unfold puts data into data-value="{{ data }}" — a JSON string is required
    "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
    "datasets": [
        {
            "label": "Notes",
            "data": [12, 19, 8, 15, 22, 7, 11],
            "borderColor": "rgb(14, 165, 233)",
            "backgroundColor": "rgba(14, 165, 233, 0.1)",
            "fill": True,
        },
        {
            "label": "Comments",
            "data": [5, 8, 3, 7, 10, 2, 6],
            "borderColor": "rgb(168, 85, 247)",
        },
    ],
})
```

```html
{# Line chart #}
{% component "unfold/components/chart/line.html" with title="Activity this week" data=chart_data height=300 %}{% endcomponent %}

{# Bar chart #}
{% component "unfold/components/chart/bar.html" with title="Notes by category" data=bar_chart_data %}{% endcomponent %}
```

### Tracker — Activity Heatmap

```python
# Generating data for the Tracker (similar to GitHub contributions)
from datetime import date, timedelta
import random

def get_tracker_data():
    today = date.today()
    data = []
    for i in range(365):
        day = today - timedelta(days=i)
        count = Note.objects.filter(created_at__date=day).count()
        data.append({
            # color is a Tailwind intensity class (the Unfold tracker expects color/tooltip/href)
            "color": "bg-primary-700" if count >= 4 else "bg-primary-400" if count else "bg-base-300",
            "tooltip": f"{count} notes {day.strftime('%d.%m.%Y')}",
        })
    return list(reversed(data))
```

```html
{% component "unfold/components/tracker.html" with title="Activity over the year" data=tracker_data %}{% endcomponent %}
```

### Cohort — Retention Table

```python
# Cohort analysis — for example, user retention
cohort_data = {
    "columns": ["Week 1", "Week 2", "Week 3", "Week 4"],
    "rows": [
        {"label": "February 2025", "values": [100, 72, 58, 45]},
        {"label": "March 2025", "values": [100, 68, 51, None]},
        {"label": "April 2025", "values": [100, 71, None, None]},
    ],
}
```

```html
{% component "unfold/components/cohort.html" with title="User retention" data=cohort_data %}{% endcomponent %}
```

---

---
- **🧠 Mental model:** Information Hierarchy is the architecture of attention. When an edit form has 20+ fields, the user gets lost. Fieldset Tabs split the fields into logical groups (tabs), showing only one group at a time. Conditional Fields hide fields that are irrelevant to the current state (for example, `visible_until` is shown only if status='scheduled'). Sortable Inlines let you drag rows with the mouse — without any extra JavaScript code.
- **📚 Why Alpine.js for conditional fields:** Alpine.js is a "minimalist React" (14KB) built into Unfold. It lets you reactively show/hide DOM elements via `x-show="condition"` without writing your own JavaScript. `x-data` defines the reactive state, and `x-on:change` updates the state on an event. The browser handles showing/hiding instantly without a request to the server.
- **🌐 What happens under the hood:** Fieldset Tabs in Unfold are implemented via `'tab': True` in fieldsets. Unfold renders the tabs as a `<nav>` with a JavaScript switcher. When you click a tab, Alpine.js shows the corresponding fieldset and hides the others. The data from all tabs is sent together on a POST save (not only the active tab). Sortable Inlines use SortableJS (JavaScript) for drag-and-drop, storing the order in a hidden input.
- **❌ Common beginner mistake:** Adding `'tab': True` to only some fieldsets — some fields will end up outside the tabs and will be displayed at the bottom of the page in "raw" form. Or forgetting to set `from unfold.admin import ModelAdmin as UnfoldModelAdmin` — fieldset tabs won't be rendered by the standard `ModelAdmin`.
---

## §11. Information Hierarchy

### Fieldset Tabs — Tabs in the Form

```python
from unfold.admin import ModelAdmin as UnfoldModelAdmin

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    fieldsets = [
        (
            'Main information',
            {
                'tab': True,        # ← first tab
                'fields': ['title', 'body', 'category'],
            }
        ),
        (
            'SEO',
            {
                'tab': True,        # ← second tab
                'fields': ['slug', 'meta_title', 'meta_description'],
            }
        ),
        (
            'Publishing',
            {
                'tab': True,        # ← third tab
                'fields': ['status', 'published_at', 'is_public'],
            }
        ),
    ]
```

### Conditional Fields — Alpine.js

```python
# The visible_until field is shown only if status == 'scheduled'

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    fieldsets = [
        (
            None,
            {
                'fields': [
                    'title',
                    'status',
                    'visible_until',   # conditional field
                ],
            }
        ),
    ]
```

```html
{# templates/admin/notes_app/note/change_form.html #}
{% extends "admin/change_form.html" %}

{% block field_sets %}
<div x-data="{ status: '{{ adminform.form.initial.status }}' }">

    {# status field — updates x-data on change #}
    <div x-on:change="status = $event.target.value">
        {{ block.super }}
    </div>

    {# visible_until — shown only for scheduled #}
    <div x-show="status === 'scheduled'" x-cloak>
        {# form field #}
    </div>
</div>
{% endblock %}
```

### Sortable Inlines

```python
from unfold.contrib.inlines.admin import SortableStackedInline

class SortableAttachmentInline(SortableStackedInline):
    model = Attachment
    fields = ['file', 'description', 'order']
    sortable_field_name = 'order'   # field used for ordering (IntegerField)
    extra = 0
```

### Expandable Rows in the ChangeList

```python
from unfold.admin import ModelAdmin as UnfoldModelAdmin
from unfold.sections import TableSection

# In Unfold an expandable row is a "section" (the list_sections attribute).
# Unfold has no list_expandable_fields attribute.
class NoteCommentsSection(TableSection):
    verbose_name = 'Comments'
    related_name = 'comments'          # reverse FK: note.comments
    fields = ['text', 'created_at']


@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    list_display = ['title', 'status', 'comments_count']
    # Expandable row — an expanded row with a table of comments
    list_sections = [NoteCommentsSection]
```

---

---
- **🧠 Mental model:** Enterprise Patterns are a "multi-floor office". Different teams (operations, analytics, technical support) need different "floors" with a different look and different access. `UnfoldAdminSite` + `LegacyAdminSite` let you run several admin panels on one Django server: modern Unfold for new features, the standard one for legacy workflows. `InfinitePaginator` is for tables with millions of rows where `COUNT(*)` takes seconds.
- **📚 Why `InfinitePaginator` matters:** A PostgreSQL `COUNT(*)` on a 10M-row table without conditions can take 2–5 seconds (full table scan or index scan). Standard Django pagination runs `COUNT(*)` on EVERY list load. `InfinitePaginator` uses `LIMIT N+1` instead of COUNT: if you got N+1 rows, there is another page; if fewer than N+1, this is the last one. No total count is computed.
- **🌐 What happens under the hood:** `import/export + Unfold` — Unfold replaces the standard `django-import-export` templates with its own Tailwind-styled versions. `unfold.contrib.import_export` contains overridden templates for the Import/Export buttons and modal windows. Django finds them first (because `unfold` is first in `INSTALLED_APPS`).
- **❌ Common beginner mistake:** Installing `unfold.contrib.import_export` but leaving `'import_export'` before `'unfold'` in `INSTALLED_APPS`. Result: the standard (non-Tailwind) import_export templates load first — the buttons look different from the rest of the admin.
---

## §12. Enterprise Patterns

### Parallel Unfold + Standard Admin

```python
# notes_app/admin_sites.py

from unfold.sites import UnfoldAdminSite
from django.contrib.admin import AdminSite

# Unfold for the new team
class ModernAdminSite(UnfoldAdminSite):
    site_header = 'Bootstrap Notes Modern'

# Standard one for legacy workflows
class LegacyAdminSite(AdminSite):
    site_header = 'Bootstrap Notes Legacy'

modern_admin = ModernAdminSite(name='modern')
legacy_admin = LegacyAdminSite(name='legacy')
```

```python
# urls.py
urlpatterns = [
    path('admin/', admin.site.urls),            # standard Django Admin
    path('modern/', modern_admin.urls),         # Unfold
    path('legacy/', legacy_admin.urls),         # legacy AdminSite
]
```

### InfinitePaginator — Without COUNT(*)

```python
from unfold.paginator import InfinitePaginator

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    paginator = InfinitePaginator    # ← no COUNT(*) query
    list_per_page = 50
    show_full_result_count = False   # hide "X results (Y total)"
```

> **Why:** `SELECT COUNT(*) FROM notes` on a table with 10M rows can take seconds.
> `InfinitePaginator` uses `LIMIT/OFFSET` without counting the total number of rows.

### crispy-forms + Unfold

```bash
pip install crispy-tailwind
```

```python
# settings.py
INSTALLED_APPS = [
    'unfold',
    'unfold.contrib.forms',    # ← Unfold forms
    'crispy_forms',
    'crispy_tailwind',
    ...
]

CRISPY_ALLOWED_TEMPLATE_PACKS = "tailwind"
CRISPY_TEMPLATE_PACK = "tailwind"
```

```python
# forms.py — crispy with Unfold styles
from crispy_forms.helper import FormHelper
from crispy_forms.layout import Layout, Submit, Row, Column

class NoteForm(forms.ModelForm):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.helper = FormHelper()
        self.helper.layout = Layout(
            'title',
            Row(Column('category'), Column('status')),
            'body',
            Submit('submit', 'Save', css_class='btn-primary'),
        )
```

### import/export + Unfold

```bash
pip install django-import-export
```

```python
# settings.py
INSTALLED_APPS = [
    'unfold',
    'unfold.contrib.import_export',  # ← instead of 'import_export'
    'import_export',
    ...
]
```

```python
from import_export.admin import ImportExportModelAdmin
from unfold.admin import ModelAdmin as UnfoldModelAdmin
from import_export import resources


class NoteResource(resources.ModelResource):
    class Meta:
        model = Note
        fields = ['id', 'title', 'body', 'status', 'created_at']


@admin.register(Note)
class NoteAdmin(ImportExportModelAdmin, UnfoldModelAdmin):
    resource_classes = [NoteResource]
    # → Import/Export buttons appear in the ChangeList
```

### Command Palette (Ctrl+K)

```python
# settings.py — global search
UNFOLD = {
    ...
    "COMMAND_PALETTE": {
        "show_search": True,
        # search_fields are taken from ModelAdmin.search_fields
        # Warning: this can put load on the DB!
        # Configure search_fields with ^ or = prefixes
    },
}
```

> **Production warning:** The command palette searches across all registered models at the same time. Make sure every `ModelAdmin` has `search_fields` with indexed fields.

---

---
- **🧠 Mental model:** Anti-Patterns are "looks good now, hurts later". Each of the listed anti-patterns has a short-term benefit ("less code now") and a long-term cost ("an XSS vulnerability", "crashing under load", "a concurrency bug"). Studying anti-patterns saves you from technical debt.
- **📚 Why `format_html` and not `mark_safe`:** `mark_safe(f'<b>{obj.title}</b>')` — the Python f-string interpolates `obj.title` directly. If title = `'<script>alert("xss")</script>'`, the template renders a real `<script>` tag. An XSS attack. `format_html('<b>{}</b>', obj.title)` automatically escapes the second argument: `<script>` → `&lt;script&gt;`. Safe, even if title is user-generated content.
- **🌐 What happens under the hood:** Internally, Django's `format_html` calls `conditional_escape()` for each argument that is not `SafeData`. This converts `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&#x27;`, `&` → `&amp;`. The result is a string marked as `SafeData`, which the Django Template will not escape again.
- **❌ Common beginner mistake:** Thinking "my admin is password-protected — XSS is not a problem". XSS in the admin is especially dangerous: if an attacker can enter JavaScript into a note's title, and a staff user opens the list of notes in the admin, the JS runs in the context of the staff user's session with full permissions.
---

## §13. Admin Anti-Patterns

### ❌ The Admin as the Main Frontend

```python
# WRONG: business processes of external users in the admin
# The admin is for INTERNAL staff
# External users → standard Django Views + Bootstrap templates
```

### ❌ State Leakage Through Attribute Mutation

```python
# ❌ DANGEROUS: ModelAdmin is a singleton!
class NoteAdmin(admin.ModelAdmin):
    readonly_fields = ['created_at']

    def get_readonly_fields(self, request, obj=None):
        if obj:
            self.readonly_fields.append('title')  # mutates the class for EVERYONE
        return self.readonly_fields

# ✅ Return a new list
    def get_readonly_fields(self, request, obj=None):
        fields = list(self.readonly_fields)  # a copy
        if obj:
            fields.append('title')
        return fields
```

### ❌ XSS via mark_safe

```python
# ❌ DANGEROUS: user-generated content without escaping
def colored_title(self, obj):
    return mark_safe(f'<b>{obj.title}</b>')  # title may contain <script>!

# ✅ format_html escapes automatically
from django.utils.html import format_html

def colored_title(self, obj):
    return format_html('<b>{}</b>', obj.title)  # safe
```

### ❌ Slow search_fields Without Indexes

```python
# ❌ Full scan on a TEXT field
search_fields = ['body']  # WHERE body LIKE '%query%' — no index!

# ✅ Search on indexed fields
search_fields = ['^title']   # startswith — uses a btree index
# Or add a GIN index for full-text search in PostgreSQL:
# CREATE INDEX idx_note_body_gin ON notes_app_note USING gin(to_tsvector('simple', body));
```

### ❌ Custom URLs Without admin_view

```python
# ❌ Unprotected endpoint
def get_urls(self):
    return [
        path('export/', self.export_view),  # OPEN TO EVERYONE!
    ] + super().get_urls()

# ✅ The admin_view wrapper guarantees authentication
def get_urls(self):
    return [
        path('export/',
             self.admin_site.admin_view(self.export_view)),  # protected
    ] + super().get_urls()
```

### ❌ N+1 in list_display Without list_select_related

```python
# ❌ 1 + N queries (N = number of notes on the page)
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'author_email']

    def author_email(self, obj):
        return obj.author.email  # a SELECT for every row

# ✅
class NoteAdmin(admin.ModelAdmin):
    list_display = ['title', 'author_email']
    list_select_related = ['author']  # JOIN once

    def author_email(self, obj):
        return obj.author.email  # from the cache
```

---

## §14. Self-Check Questions

1. `ModelAdmin` is effectively a singleton (one instance per model within an `AdminSite`). What does this mean for the `get_readonly_fields()` method? Why is mutating `self.readonly_fields` dangerous?
2. Why do you need `self.admin_site.admin_view()` when adding a custom URL in `get_urls()`? What happens without it?
3. `list_select_related = True` vs `list_select_related = ['author', 'category']` — what is the difference?
4. `search_fields = ['body']` on a table with 1M rows. What happens in the DB? How do you fix it?
5. `TemplateResponse` in `changelist_view` allows middleware to change the context. How can you use this for A/B testing?
6. Unfold's `InfinitePaginator` does not run `COUNT(*)`. What limitations does this impose on the UX? When is it acceptable?
7. Why can the Command Palette be dangerous in production without the right `search_fields` configuration?
8. `DASHBOARD_CALLBACK` receives `(request, context)` — how is this different from a standard Context Processor?
9. `SortableStackedInline` requires an `IntegerField` in the model. Why? How is this field stored in the DB?
10. Can you run the standard `django.contrib.admin.site` and an `UnfoldAdminSite` at the same time on different URLs? What is the practical advantage of this in an enterprise setting?

---

---
- **🧠 Mental model:** Unfold Filters are "smart search" instead of a "dumb dropdown". A standard `list_filter = ['author']` for a FK with 100k users loads ALL of them into a `<select>` — the page freezes. `AutocompleteSelectFilter` loads only 10 results via AJAX as you type. `RangeDateFilter` shows "from/to" fields instead of a list of years. `TextFilter` is a text field with custom logic.
- **📚 Why `list_filter_submit = True` is mandatory for some filters:** Without `list_filter_submit`, every filter change immediately sends a request to the server (the standard behavior). For `RangeDateFilter` and `TextFilter`, which are input fields, this would mean a request after every keystroke. `list_filter_submit = True` adds an "Apply" button and sends the request only after explicit confirmation.
- **🌐 What happens under the hood:** Under the hood, `AutocompleteSelectFilter` uses Django's built-in autocomplete API: `GET /admin/autocomplete/?term=john&app_label=notes_app&model_name=note&field_name=author`. Django Admin runs a `search_fields` query on UserAdmin and returns JSON with the results. That's why `search_fields` on `UserAdmin` is MANDATORY for `AutocompleteSelectFilter` to work.
- **❌ Common beginner mistake:** Hooking up `AutocompleteSelectFilter` for the `author` FK but not adding `search_fields` to `UserAdmin`. Django will return `Http404` or `ImproperlyConfigured` on the autocomplete AJAX request. Rule: if a FK points to model X, then `XAdmin` MUST have `search_fields`.
---

## §15. Advanced Filtering — Unfold Filters

### Unfold's Built-in Filters

```python
# settings.py
INSTALLED_APPS = [
    'unfold',
    'unfold.contrib.filters',   # ← required
    ...
]
```

```python
# notes_app/admin.py
from unfold.contrib.filters.admin import (
    AutocompleteSelectFilter,       # Select2 search for FK
    AutocompleteSelectMultipleFilter,
    RangeDateFilter,                # date range picker
    RangeDateTimeFilter,
    RangeNumericFilter,             # numeric range
    TextFilter,                     # text filter with an input field
    DropdownFilter,                 # standard dropdown
    RelatedDropdownFilter,          # FK dropdown
    ChoicesDropdownFilter,          # choices field dropdown
)

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    list_filter_submit = True       # ← "Apply" button in filters

    list_filter = [
        ('status', ChoicesDropdownFilter),          # dropdown for choices
        ('category', RelatedDropdownFilter),        # FK dropdown
        ('author', AutocompleteSelectFilter),       # Select2 AJAX
        ('created_at', RangeDateFilter),            # from/to for a date
    ]
```

### TextFilter — a Custom Text Filter

```python
from unfold.contrib.filters.admin import TextFilter

class TitleTextFilter(TextFilter):
    title = 'Search by title'
    parameter_name = 'title_contains'

    def queryset(self, request, queryset):
        if self.value():
            return queryset.filter(title__icontains=self.value())
        return queryset


@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    list_filter = [TitleTextFilter]
```

### AutocompleteSelectFilter for Large FKs

```python
# ❌ Standard list_filter for a FK with 100k records
list_filter = ['author']
# → SELECT * FROM auth_user → loads ALL records into a <select>

# ✅ AutocompleteSelectFilter — AJAX search
from unfold.contrib.filters.admin import AutocompleteSelectFilter

list_filter = [('author', AutocompleteSelectFilter)]
list_filter_submit = True

from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User

# UserAdmin must have search_fields
admin.site.unregister(User)  # User is already registered by django.contrib.auth

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    search_fields = ['^username', '^email']  # ← required
```

### RangeDateTimeFilter — a Date Range

```python
from unfold.contrib.filters.admin import RangeDateTimeFilter

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    list_filter = [
        ('created_at', RangeDateTimeFilter),  # → "From: [date] To: [date]"
    ]
    list_filter_submit = True  # without submit, the filter doesn't fire!
```

---

---
- **🧠 Mental model:** Actions are "bulk operations". The standard Django "select all + delete" is also an action. Unfold extends the actions system with three levels: (1) Bulk actions (for the selected records in the list), (2) Dialog actions (a bulk action with a confirmation form), (3) Row-level actions (for each row individually). A dialog action is "two steps instead of one": first a form (reason, parameters), then the action.
- **📚 Why Dialog Actions instead of a simple confirmation:** The browser's `confirm()` is a blocking modal window with no way to enter data. `BaseDialogForm` is a full Django form in a modal window: input fields, validation, Unfold styles (Tailwind CSS). For example, when archiving a note, ask for the reason and whether to notify the author. This data is passed in `request.POST` and is available in the action method.
- **🌐 What happens under the hood:** Bulk action flow: (1) The user selects checkboxes in the ChangeList, (2) Picks an action from the dropdown, (3) A POST request to `/admin/notes_app/note/` with `action='publish_notes'` and `_selected_action=[1, 2, 3]`, (4) Django finds the `publish_notes` method in `NoteAdmin.actions`, (5) Calls `publish_notes(modeladmin, request, queryset)`, where `queryset` is already filtered to the selected records.
- **❌ Common beginner mistake:** Running an expensive operation (for example, sending email) synchronously in a bulk action. If you select 1000 records and click "Archive and notify", the HTTP request will take minutes. The browser may lose the connection. Heavy operations in bulk actions should always go through a Celery task.
---

## §16. Bulk Actions and Dialog Actions

### Standard Actions + the Unfold Decorator

```python
from unfold.decorators import action

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    actions = ['publish_notes', 'delete_with_confirm']

    @action(
        description='Publish',
        icon='publish',
        attrs={'class': 'text-green-600 font-semibold'},
    )
    def publish_notes(self, request, queryset):
        count = queryset.update(status='published')
        self.message_user(request, f'Published {count} notes.')
```

### Dialog Action — Confirmation with a Form

```python
from unfold.actions import BaseDialogForm, BaseActionForm
from django import forms

class ArchiveReasonForm(BaseDialogForm):
    """Form for the dialog window shown before archiving."""
    reason = forms.CharField(
        label='Archiving reason',
        widget=forms.Textarea(attrs={'rows': 3}),
        required=True,
    )
    notify_author = forms.BooleanField(
        label='Notify the author',
        required=False,
        initial=True,
    )


@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    actions = ['archive_with_reason']

    @action(
        description='Archive with an explanation',
        icon='archive',
        form=ArchiveReasonForm,                 # ← opens a modal window
    )
    def archive_with_reason(self, request, queryset):
        # After the form is filled in, request.POST is available here
        reason = request.POST.get('reason', '')
        notify = request.POST.get('notify_author') == 'on'

        for note in queryset:
            note.status = 'archived'
            note.archive_reason = reason
            note.save()
            if notify:
                send_mail(
                    subject='Your note has been archived',
                    message=f'Reason: {reason}',
                    recipient_list=[note.author.email],
                    from_email=settings.DEFAULT_FROM_EMAIL,
                )

        self.message_user(request, f'Archived {queryset.count()} notes.')
```

### Row-Level Actions (Actions on Each Row)

```python
from unfold.admin import ModelAdmin as UnfoldModelAdmin

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):

    @action(description='Duplicate', icon='content_copy', url_path='duplicate')
    def duplicate_note(self, request, pk):
        """Row-level action — for each row individually."""
        note = get_object_or_404(Note, pk=pk)
        note.pk = None
        note.title = f'[Copy] {note.title}'
        note.status = 'draft'
        note.save()
        self.message_user(request, f'Note duplicated.')
        return redirect(
            reverse('admin:notes_app_note_changelist')
        )
```

---

---
- **🧠 Mental model:** Component Classes are a "separate department" for each dashboard block. Instead of one big `dashboard_callback` that does everything, each component (activity chart, top-authors table, tracker) is a separate class with its own `get_context_data()`. This is "separation of concerns" in its purest form: tested separately, updated separately, cached separately.
- **📚 Why `apps.py → ready()` for registration:** `@register_component` registers the component in a global registry when the module is imported. But Python doesn't import the module automatically — only if it is explicitly imported. `apps.py → ready()` is the right place for "side effects at Django startup": it runs after all models and settings have been fully loaded. `import notes_app.admin_components` in `ready()` triggers the registration.
- **🌐 What happens under the hood:** `{% component "unfold/components/card.html" with component_class="NoteActivityChartComponent" %}` — Unfold finds the class in the registry by its class name (`component_class`), creates an instance, calls `get_context_data()`, and renders the `card.html` template and the contents of the component block in that context. The content between `{% component %}` and `{% endcomponent %}` is the component's template, which has access to the data from `get_context_data()`.
- **❌ Common beginner mistake:** Forgetting `import notes_app.admin_components` in `apps.py → ready()`. The components won't be registered. `{% component "..." %}` will silently display nothing or throw `ComponentNotFound`. Check: after stopping and restarting the server, a `ComponentNotFound` error → `ready()` is not importing the required module.
---

## §17. Component Classes — `@register_component`

### Why Component Classes

```
❌ Dashboard callback with heavy logic:
def dashboard_callback(request, context):
    context['chart'] = {
        'labels': [...heavy ORM aggregation...],
        'data': [...more complex stuff...],
    }
    # Everything mixed together in one function

✅ Component Class — the logic is isolated:
@register_component
class NoteActivityChart:
    def get_context_data(self, **kwargs):
        return {'labels': [...], 'data': [...]}
```

### Registration and Usage

```python
# notes_app/admin_components.py

import json

from unfold.components import BaseComponent, register_component
from django.db.models import Count
from django.db.models.functions import TruncDate
from datetime import timedelta
from django.utils import timezone


@register_component
class NoteActivityChartComponent(BaseComponent):
    """Line chart of activity over 30 days."""

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        thirty_days_ago = timezone.now() - timedelta(days=30)
        daily = (
            Note.objects
            .filter(created_at__gte=thirty_days_ago)
            .annotate(date=TruncDate('created_at'))
            .values('date')
            .annotate(count=Count('id'))
            .order_by('date')
        )

        context['chart_data'] = json.dumps({
            'labels': [str(row['date']) for row in daily],
            'datasets': [{
                'label': 'New notes',
                'data': [row['count'] for row in daily],
                'borderColor': 'rgb(14, 165, 233)',
                'backgroundColor': 'rgba(14, 165, 233, 0.1)',
                'fill': True,
            }],
        })
        context['title'] = 'Activity over 30 days'
        return context


@register_component
class TopAuthorsTableComponent(BaseComponent):
    """Top 5 authors by number of notes."""

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        top_authors = (
            Note.objects
            .values('author__username')
            .annotate(count=Count('id'))
            .order_by('-count')[:5]
        )
        context['authors'] = top_authors
        return context
```

```python
# notes_app/apps.py — so that the components get loaded
class HelloAppConfig(AppConfig):
    name = 'notes_app'

    def ready(self):
        import notes_app.admin_components  # ← component registration
```

```html
{# templates/admin/index.html #}
{% extends "unfold/layouts/base_simple.html" %}
{% load unfold %}

{% block content %}
<div class="grid grid-cols-1 gap-6 lg:grid-cols-2">

    {# Component Class — automatically calls get_context_data() #}
    {% component "unfold/components/card.html" with component_class="NoteActivityChartComponent" %}
    {% component "unfold/components/chart/line.html" with data=chart_data %}
    {% endcomponent %}
    {% endcomponent %}

    {% component "unfold/components/card.html" with component_class="TopAuthorsTableComponent" %}
    <table class="w-full text-sm">
        {% for author in authors %}
        <tr>
            <td>{{ author.author__username }}</td>
            <td class="text-right font-bold">{{ author.count }}</td>
        </tr>
        {% endfor %}
    </table>
    {% endcomponent %}

</div>
{% endblock %}
```

---

---
- **🧠 Mental model:** Custom Pages are "your own room in the office". The standard admin only knows CRUD (list, form, deletion). If you need an analytics page, a report, or a custom form not tied to a model — `UnfoldModelAdminViewMixin + TemplateView`. This is a Django Class-Based View inside the admin, with Unfold styles, the sidebar, breadcrumbs, and permission checks — but with its own template and logic.
- **📚 Why `admin_view()` is mandatory:** `self.admin_site.admin_view(view)` is a decorator that wraps the view and adds: (1) an authentication check (redirect to login if not logged in), (2) an `is_staff` check (403 if not staff), (3) a CSRF check. Without it, your custom page is open to everyone without authorization. This is a critical security vulnerability.
- **🌐 What happens under the hood:** `NoteStatisticsView.as_view(model_admin=self)` — `model_admin` is passed to the view via `kwargs`. `UnfoldModelAdminViewMixin` uses `model_admin` to access `admin_site.each_context()` (global admin context variables: permissions, messages, sidebar data). Without `model_admin`, the Unfold template can't build the sidebar and navbar.
- **❌ Common beginner mistake:** Registering a custom page in `get_urls()` but forgetting to add a link to it in `UNFOLD.SIDEBAR`. The page is technically accessible (if you know the URL), but unreachable through the interface. Or registering the URL without `name=` — then `reverse_lazy('admin:...')` in the sidebar will raise `NoReverseMatch`.
---

## §18. Custom Pages — UnfoldModelAdminViewMixin

### A Custom Page Inside Unfold

```python
# notes_app/admin_views.py

from django.contrib.auth.mixins import LoginRequiredMixin
from django.views.generic import TemplateView
from unfold.views import UnfoldModelAdminViewMixin


class NoteStatisticsView(UnfoldModelAdminViewMixin, TemplateView):
    """Custom statistics page with Unfold styles."""
    title = 'Note statistics'       # shown in the header
    permission_required = ()         # or ('notes_app.view_note',)
    template_name = 'admin/notes_app/note_statistics.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['stats'] = {
            'by_status': Note.objects.values('status').annotate(
                count=Count('id')
            ),
            'by_month': Note.objects.annotate(
                month=TruncMonth('created_at')
            ).values('month').annotate(count=Count('id')).order_by('month'),
        }
        return context
```

```python
# notes_app/admin.py — URL registration

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):

    def get_urls(self):
        from django.urls import path
        from notes_app.admin_views import NoteStatisticsView

        urls = super().get_urls()
        custom = [
            path(
                'statistics/',
                self.admin_site.admin_view(           # ← authentication protection
                    NoteStatisticsView.as_view(
                        model_admin=self              # ← pass the ModelAdmin
                    )
                ),
                name='notes_app_note_statistics',
            ),
        ]
        return custom + urls
```

```python
# settings.py — add the page to the sidebar
UNFOLD = {
    "SIDEBAR": {
        "navigation": [
            {
                "title": "Analytics",
                "items": [
                    {
                        "title": "Note statistics",
                        "icon": "bar_chart",
                        "link": reverse_lazy("admin:notes_app_note_statistics"),
                    },
                ],
            },
        ],
    },
}
```

```html
{# templates/admin/notes_app/note_statistics.html #}
{% extends "unfold/layouts/base.html" %}
{% load i18n unfold %}

{% block breadcrumbs %}
<a href="{% url 'admin:notes_app_note_changelist' %}">Notes</a> /
<span>Statistics</span>
{% endblock %}

{% block content %}
<div class="flex flex-col gap-6">
    <h1 class="text-2xl font-bold">Note statistics</h1>

    {# By status #}
    <div class="grid grid-cols-3 gap-4">
        {% for item in stats.by_status %}
        {% component "unfold/components/card.html" with title=item.status %}{% component "unfold/components/title.html" %}{{ item.count }}{% endcomponent %}{% endcomponent %}
        {% endfor %}
    </div>
</div>
{% endblock %}
```

---

---
- **🧠 Mental model:** Advanced Widgets are "special tools for special fields". A standard `<textarea>` for text is a "hammer". `WysiwygWidget` is a "power drill": a WYSIWYG editor with formatting (bold, italic, lists, links) right in the admin. `ArrayWidget` is a "set of tags": editing a PostgreSQL array as a set of tag chips. `autocomplete_fields` is "smart search" instead of a "huge select".
- **📚 Why `formfield_for_dbfield` and not `widgets` in Meta:** `formfield_for_dbfield` allows conditional logic: a different widget depending on the field name, the field type, or even the request (for example, a different widget for a superuser and regular staff). `widgets` in `ModelForm.Meta` is a static configuration with no conditions. For custom Unfold widgets, always use `formfield_for_dbfield`.
- **🌐 What happens under the hood:** `WysiwygWidget` renders a Trix (or TipTap) JavaScript editor. When the form loads, the textarea turns into a rich-text editor (JS initialization). On save, the JS serializes the formatted content into an HTML string and writes it to a hidden textarea. Django receives the HTML string in `request.POST` and saves it in a `TextField`. On display, `{{ note.body|safe }}` shows the HTML.
- **❌ Common beginner mistake:** Storing WYSIWYG HTML in a `TextField` and displaying it via `{{ note.body }}` (without `|safe`) in public templates — the text will be displayed as `&lt;p&gt;...&lt;/p&gt;`. Or the other way round: `{{ user_comment|safe }}` for user-generated content without WYSIWYG — a direct XSS vulnerability. Rule: `|safe` only for content edited through a trusted WYSIWYG in a closed admin.
---

## §19. Advanced Widgets

### WysiwygWidget — a WYSIWYG Editor (Trix)

```python
pip install django-trix  # or the built-in unfold Trix
```

```python
from unfold.contrib.forms.widgets import WysiwygWidget

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        if db_field.name == 'body':
            kwargs['widget'] = WysiwygWidget
        return super().formfield_for_dbfield(db_field, request, **kwargs)
```

### ArrayWidget — PostgreSQL Array Fields

```python
# models.py — PostgreSQL ArrayField
from django.contrib.postgres.fields import ArrayField

class Note(models.Model):
    tags = ArrayField(
        models.CharField(max_length=50),
        default=list,
        blank=True,
    )
```

```python
from unfold.contrib.forms.widgets import ArrayWidget

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):

    def formfield_for_dbfield(self, db_field, request, **kwargs):
        if db_field.name == 'tags':
            kwargs['widget'] = ArrayWidget
        return super().formfield_for_dbfield(db_field, request, **kwargs)
        # → renders tags as chips that can be added/removed
```

### Autocomplete FK — Replacing the Select

```python
@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    # ❌ The standard FK <select> loads all users
    # (raw_id_fields = ['author'] doesn't load them all, but shows only an ID field — worse UX)

    # ✅ AJAX search — doesn't load everyone
    autocomplete_fields = ['author', 'category']

    # Required on UserAdmin and CategoryAdmin:
    # search_fields = ['^username']  or  search_fields = ['^name']
```

---

---
- **🧠 Mental model:** Admin Performance is "screening at the entrance". The cache is a "doorman with a memory": the first time, he lets you in, checks your documents (runs the SQL), and writes down the result. The next time, he just opens the door without checking. `cache.set(key, value, timeout=300)` → 5 minutes without SQL. `cache.delete(key)` when the data changes → "the doorman forgets" → the next request is checked again.
- **📚 Why `cached.Loader` is critical in production:** Without `cached.Loader`, Django reads the template file from disk and parses it on EVERY request. 1000 requests/second = 1000 disk reads + 1000 parses. `cached.Loader` parses once on the first request and keeps the compiled Node tree in RAM. The next 999 requests only render from RAM. A 10–50x speedup in template rendering.
- **🌐 What happens under the hood:** PostgreSQL Full-Text Search with `SearchVector` and a `GIN` index: `to_tsvector('simple', title || ' ' || body)` converts the text into lexemes (normalized words; standard PostgreSQL has no `ukrainian` configuration, so use `simple` or a custom hunspell configuration). `SearchQuery('django')` is normalized too. GIN is an inverted index: it stores a `{lexeme → [doc_id, ...]}` mapping (the lexeme keys themselves are organized in an internal tree). The search is a fast lexeme lookup in the GIN index instead of a `LIKE '%query%'` full scan.
- **❌ Common beginner mistake:** Enabling `cached.Loader` in development. When you change a template, the browser shows the old version. You need to restart the server to refresh the cache. `cached.Loader` is EXCLUSIVELY for production. In development, keep `APP_DIRS: True`. A version note: since Django 4.1, when `loaders` is not set explicitly, the cached loader is enabled automatically in development too, and the dev server resets the cache when a template changes — explicit configuration is needed only for a custom list of loaders.
---

## §20. Performance and Caching

### Caching Dashboard Data

```python
# notes_app/admin_dashboard.py

from django.core.cache import cache
from django.db.models import Count


def dashboard_callback(request, context):
    # Try to get it from the cache
    cache_key = 'admin_dashboard_stats'
    stats = cache.get(cache_key)

    if stats is None:
        # Heavy query — runs only if the cache is empty
        stats = {
            'total': Note.objects.count(),
            'published': Note.objects.filter(status='published').count(),
            'by_category': list(
                Note.objects.values('category__name')
                .annotate(count=Count('id'))
                .order_by('-count')[:10]
            ),
        }
        cache.set(cache_key, stats, timeout=300)  # 5 minutes

    context['stats'] = stats

    # Cache invalidation — in a signal or save_model
    return context
```

```python
# Invalidation when a note is saved
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.core.cache import cache

@receiver(post_save, sender=Note)
def invalidate_dashboard_cache(sender, **kwargs):
    cache.delete('admin_dashboard_stats')
```

### The `{% cache %}` Template Tag for Heavy Blocks

```html
{# templates/admin/index.html #}
{% load cache %}

{# Cache the HTML fragment for 5 minutes #}
{% cache 300 "dashboard_top_authors" %}
    {% component "unfold/components/card.html" with title="Top authors" %}{% component "unfold/components/table.html" with table=top_authors %}{% endcomponent %}{% endcomponent %}
{% endcache %}
```

### cached.Loader for Templates in Production

```python
# settings.py — production
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': False,     # ← False when using cached.Loader
        'OPTIONS': {
            'loaders': [
                ('django.template.loaders.cached.Loader', [
                    'django.template.loaders.filesystem.Loader',
                    'django.template.loaders.app_directories.Loader',
                ]),
            ],
            'context_processors': [...],
        },
    },
]
```

### Full-Text Search in PostgreSQL

```python
# ❌ LIKE on a large table
search_fields = ['body']  # WHERE body LIKE '%query%' — full scan

# ✅ PostgreSQL Full-Text Search
from django.contrib.postgres.search import SearchVector, SearchQuery, SearchRank

@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    search_fields = ['title']  # fallback for simple search

    def get_search_results(self, request, queryset, search_term):
        if search_term and len(search_term) >= 3:
            # Full-text search on title + body
            search_vector = SearchVector('title', weight='A', config='simple') + \
                            SearchVector('body', weight='B', config='simple')
            search_query = SearchQuery(search_term, config='simple')  # standard PostgreSQL has no 'ukrainian' configuration — use 'simple' or a custom one (hunspell)

            queryset = (
                queryset
                .annotate(search=search_vector)
                .filter(search=search_query)
                .annotate(rank=SearchRank(search_vector, search_query))
                .order_by('-rank')
            )
            return queryset, False  # False = no distinct needed

        return super().get_search_results(request, queryset, search_term)
```

```python
# Migration: GIN index for full-text search
# notes_app/migrations/0002_note_search_index.py

from django.db import migrations

class Migration(migrations.Migration):
    atomic = False  # CREATE INDEX CONCURRENTLY cannot run inside a transaction

    dependencies = [('notes_app', '0001_initial')]

    operations = [
        migrations.RunSQL(
            "CREATE INDEX CONCURRENTLY idx_note_fts ON notes_app_note "
            "USING gin(to_tsvector('simple', title || ' ' || body));",
            reverse_sql="DROP INDEX IF EXISTS idx_note_fts;",
        ),
    ]
```

### collectstatic for Production

```python
# settings.py
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Hashed files for aggressive browser caching
# Django 4.2+: STORAGES (STATICFILES_STORAGE was removed in Django 5.1)
STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.ManifestStaticFilesStorage'},
}
# → main.css → main.02b59bcc5cd9.css
# → The browser caches it for a year (immutable)
# → After the file changes, the hash changes → forced refresh
```

```bash
python manage.py collectstatic --noinput
# → collects all static files + admin/unfold assets
# → generates staticfiles.json with the mapping
```

---

---
- **🧠 Mental model:** Datasets are a "table inside the form". A standard Inline shows 5–10 related records without pagination. If a note has 500 comments, the Inline will load them all at once (slow, too much). A Dataset is an embedded ChangeList with pagination, filters, and search. It is a "mini-admin for related records" right inside the parent object's form.
- **📚 Why a partial view via a URL instead of an Inline:** An Inline runs its queryset synchronously when the form loads. 500 comments = 1 heavy SQL query + rendering 500 rows. The Dataset view runs as a separate HTTP request (via an `<iframe>` or HTMX), after the main form has loaded. The form loads quickly, and the comments load asynchronously.
- **🌐 What happens under the hood:** `comments_dataset_view` is a standard Django view registered in `get_urls()`. It runs as a separate HTTP request (GET `/admin/notes_app/note/42/comments/?page=2`). `self.admin_site.each_context(request)` adds the standard admin context variables (permissions, sidebar, messages) so that the partial template looks like part of the admin.
- **❌ Common beginner mistake:** Forgetting `**self.admin_site.each_context(request)` in the dataset view's context. The Dataset template won't have access to `user`, `site_header`, or the sidebar navigation — it will be displayed without the admin styles or throw a `KeyError`.
---

## §21. Datasets — Related Records in the ChangeForm

### What a Dataset Is

Datasets let you embed a complete ChangeList (a list of related records)
directly into the parent object's edit form.

Newer versions of `django-unfold` have a built-in Datasets API: `BaseDataset` + `change_form_datasets`:

```python
from unfold.admin import ModelAdmin as UnfoldModelAdmin
from unfold.datasets import BaseDataset


class CommentDatasetAdmin(UnfoldModelAdmin):
    list_display = ['author', 'text', 'created_at']
    search_fields = ['text']

    def get_queryset(self, request):
        # extra_context["object"] is the pk of the parent note
        return super().get_queryset(request).filter(note_id=self.extra_context.get('object'))


class CommentDataset(BaseDataset):
    model = Comment
    model_admin = CommentDatasetAdmin
    tab = True                       # show it as a tab of the form


@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    change_form_datasets = [CommentDataset]
```

Datasets are rendered together with the form (no separate request is needed). The explanations above about a separate HTTP request and `each_context()` apply to the manual variant below — your own partial view:

```python
from django.core.paginator import Paginator
from django.shortcuts import get_object_or_404, render
from unfold.admin import ModelAdmin as UnfoldModelAdmin

# Manual variant — a partial view with pagination instead of a standard Inline
@admin.register(Note)
class NoteAdmin(UnfoldModelAdmin):
    # Tabs for the form
    fieldsets = [
        ('Main information', {'tab': True, 'fields': ['title', 'body']}),
        ('Comments', {'tab': True, 'fields': []}),   # empty fieldset for the tab
    ]

    def get_urls(self):
        from django.urls import path
        urls = super().get_urls()
        extra = [
            path(
                '<int:note_id>/comments/',
                self.admin_site.admin_view(self.comments_dataset_view),
                name='notes_app_note_comments',
            ),
        ]
        return extra + urls

    def comments_dataset_view(self, request, note_id):
        """Partial page with comments for HTMX/iframe."""
        note = get_object_or_404(Note, pk=note_id)
        comments = note.comments.select_related('author').order_by('-created_at')
        paginator = Paginator(comments, 20)
        page_obj = paginator.get_page(request.GET.get('page', 1))
        return render(request, 'admin/notes_app/note/comments_dataset.html', {
            'note': note,
            'page_obj': page_obj,
            **self.admin_site.each_context(request),
        })
```

---

---
- **🧠 Mental model:** The Production Checklist is a "pre-flight checklist". Pilots don't rely on memory — they always go through the checklist. The same goes for a production Django Admin: each item closes a specific category of risk (security, performance, UX, architecture). Skipping any item is a potential problem in production.
- **📚 Why ManifestStaticFilesStorage is critical:** Without ManifestStaticFilesStorage, the browser caches `main.css` aggressively (for months). After deploying a new version, users see the old styles because the browser shows the cached version. ManifestStaticFilesStorage adds a hash to the file name: `main.02b59bcc.css`. When the file changes, the hash changes → a new name → the browser downloads the new version. The old version is cached indefinitely (cache-busting).
- **🌐 What happens under the hood:** `collectstatic` with `ManifestStaticFilesStorage`: (1) collects all static files into `STATIC_ROOT`, (2) computes the MD5 hash of each file, (3) creates copies with the hash in the name: `main.css` → `main.02b59bcc.css`, (4) generates `staticfiles.json` — a `{'main.css': 'main.02b59bcc.css'}` mapping. `{% static 'main.css' %}` → reads `staticfiles.json` → returns `main.02b59bcc.css`.
- **❌ Common beginner mistake:** Running a production server with `DEBUG=True` "temporarily". `DEBUG=True` in production means: (1) Django shows a traceback with the call stack on every error (leaking the internal structure of your code), (2) Django serves static files itself (slowly), (3) Django keeps every SQL query in memory (`connection.queries`), so process memory keeps growing. (`ALLOWED_HOSTS` is still checked; an empty list with `DEBUG=True` allows only localhost.) Never use `DEBUG=True` in production.
---

## §22. Production Checklist

```
Django Admin + Unfold — Production Checklist
─────────────────────────────────────────────

SECURITY
✅ All custom URLs are wrapped in admin_view()
✅ Permission checks in has_*_permission() methods
✅ format_html() instead of mark_safe() for user content
✅ search_fields don't contain TEXT fields without indexes
✅ autocomplete_fields for large FKs
✅ Command Palette disabled or limited by search_fields

PERFORMANCE
✅ list_select_related for all FKs in list_display
✅ prefetch_related in get_queryset() for M2M / reverse FKs
✅ InfinitePaginator for tables > 100k rows
✅ search_fields with ^ or = prefixes (or get_search_results())
✅ Dashboard data cached via cache.set/get (Redis)
✅ cached.Loader in TEMPLATES for production (APP_DIRS: False)
✅ ManifestStaticFilesStorage + collectstatic

ARCHITECTURE
✅ Unfold installed BEFORE django.contrib.admin in INSTALLED_APPS
✅ DASHBOARD_CALLBACK isolated from view logic
✅ Component Classes for heavy aggregations on the dashboard
✅ Custom pages via UnfoldModelAdminViewMixin
✅ Sidebar navigation declared in UNFOLD.SIDEBAR
✅ No HTML strings in Python (only format_html())
✅ No direct DB queries in list_display methods (without select_related)

UX
✅ list_filter_submit = True for filters with input fields
✅ warn_unsaved_form = True to warn about unsaved changes
✅ Fieldset tabs for forms with > 10 fields
✅ autocomplete_fields instead of raw_id_fields (better UX)
✅ Unfold dark mode configured via THEME or CSS variables
```
