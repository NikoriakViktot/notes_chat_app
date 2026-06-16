# Django Admin

> У Кроці 1 ти вже реєстрував `NoteAdmin` простою командою `@admin.register(Note)`.
> Тут ми розширимо його до повноцінного адмін-класу з кастомними колонками,
> пошуком, фільтрами і computed-полями.

---

## Що вже є після Кроку 1

`hello_app/admin.py` після Кроку 1:

```python
from django.contrib import admin
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    list_display    = ('title', 'created_at')
    search_fields   = ('title', 'content')
    list_filter     = ('created_at',)
    ordering        = ('-created_at',)
    readonly_fields = ('created_at',)
```

Це вже непогано. Але розглянемо кожну опцію окремо.

---

## Розширений NoteAdmin

```python
from django.contrib import admin
from django.utils.html import format_html
from .models import Note


@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    # ─── Список ────────────────────────────────────────────────────────────────
    list_display    = ['title', 'short_content', 'created_at']
    # Колонки у таблиці-списку: назва, preview тексту, дата
    # Перша колонка завжди посилання на деталь

    search_fields   = ['^title', 'content']
    # '^title' → LIKE 'search%' (швидше)  vs  'title' → LIKE '%search%'
    # 'content' → повнотекстовий пошук

    list_filter     = ['created_at']
    # Фільтри праворуч: "Будь-яка дата", "Сьогодні", "Цього тижня"...

    ordering        = ['-created_at']
    # Сортування: нові першими (Override ordering з Meta)

    list_per_page   = 20
    # Пагінація: 20 записів на сторінку

    # ─── Деталь ─────────────────────────────────────────────────────────────────
    readonly_fields = ['created_at']
    # Ці поля показуються, але не редагуються (auto_now_add → вже editable=False)

    # ─── Computed колонка ────────────────────────────────────────────────────────
    @admin.display(description='Зміст (preview)')
    def short_content(self, obj):
        """Показує перші 80 символів content у списку."""
        if not obj.content:
            return '—'
        preview = obj.content[:80] + ('...' if len(obj.content) > 80 else '')
        return format_html('<span style="color:#6b7280">{}</span>', preview)
```

---

## Анатомія ModelAdmin

### list_display

```python
list_display = ['title', 'short_content', 'created_at']
# ↑ Кожен елемент — або поле моделі, або метод класу NoteAdmin, або метод моделі

# Поле моделі:
list_display = ['title', 'created_at']

# Метод NoteAdmin з @admin.display:
@admin.display(description='Зміст (preview)')
def short_content(self, obj):
    return obj.content[:80]

# Метод моделі:
# В models.py:
def preview(self):
    return self.content[:80]
# В admin.py:
list_display = ['title', 'preview', 'created_at']
```

### search_fields — синтаксис пошуку

```python
search_fields = ['^title', 'content', '=status']
# Prefix | SQL LIKE          | Коли використовувати
# ──────────────────────────────────────────────────
# (none) | LIKE '%query%'    | Повнотекстовий (повільно на великих таблицях)
# '^'    | LIKE 'query%'     | Пошук з початку (індексується, швидше)
# '='    | = 'query'         | Точний збіг
# '@'    | Повнотекстовий    | MySQL full-text (не SQLite)
```

### list_filter — вбудовані фільтри

```python
list_filter = ['created_at', 'is_public']
# DateTimeField → автоматичні фільтри: "Будь-яка дата", "Сьогодні", "Цього тижня"...
# BooleanField → "Всі", "Так", "Ні"
```

---

## format_html — безпечний HTML в admin

```python
from django.utils.html import format_html

@admin.display(description='Статус')
def status_badge(self, obj):
    color = 'green' if obj.is_active else 'red'
    label = 'Активна' if obj.is_active else 'Архів'
    # format_html безпечно вставляє HTML:
    # → escaping для всіх {}  → захист від XSS
    return format_html(
        '<span style="color:{};font-weight:bold">{}</span>',
        color,   # ← escaped
        label,   # ← escaped
    )
    # Не конкатенуй рядки! f"<span>{obj.title}</span>" → XSS якщо title має <script>
```

---

## admin.site.register vs @admin.register

```python
# Варіант 1: admin.site.register (старий стиль)
admin.site.register(Note, NoteAdmin)

# Варіант 2: @admin.register (сучасний, декоратор)
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    ...

# Результат однаковий. @admin.register читабельніший.
```

---

## Реєстрація кількох моделей

```python
@admin.register(Note)
class NoteAdmin(admin.ModelAdmin):
    ...

@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ['name', 'slug']
    prepopulated_fields = {'slug': ('name',)}
    # prepopulated_fields: автоматично заповнює slug з name (через JS)
```

---

## Де знайти адмін-URL нотатки

```
/admin/hello_app/note/          ← список нотаток
/admin/hello_app/note/add/      ← додати нотатку
/admin/hello_app/note/42/       ← редагувати нотатку з id=42
/admin/hello_app/note/42/delete/ ← видалити
```

Формат URL: `/admin/<app_label>/<model_name>/`

`app_label` — назва з `AppConfig.label` (за замовчуванням = назва папки додатку).

---

## Що далі з Django Admin

На цьому кроці ми використовуємо стандартний `django.contrib.admin.ModelAdmin`.

У **Кроці 4 (Templates і Forms)** буде:
- `django-unfold` — Tailwind-стилізований admin замість стандартного
- `UNFOLD` config у settings.py (sidebar navigation, icons, branding)
- Ре-реєстрація `User` і `Group` через Unfold форми
