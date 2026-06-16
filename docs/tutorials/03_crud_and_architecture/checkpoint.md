# Чекпоінт: CRUD і архітектура

> Ти пройшов повний цикл від проектування домену до готового застосунку з PostgreSQL і CBV.
> Час переконатися що все зрозуміло.

---

## Що ти вмієш після цього кроку

### Проектування

- [ ] Я вмію описати домен словами перед написанням коду
- [ ] Я знаю 7 кроків методології: Домен → Сутності → Атрибути → Зв'язки → Нормалізація → on_delete → Django Модель
- [ ] Я розумію різницю між `OneToOneField`, `ForeignKey`, `ManyToManyField`
- [ ] Я знаю де живе FK (на "Many"-стороні)
- [ ] Я свідомо вибираю `on_delete` для кожного FK (не просто CASCADE)
- [ ] Я вмію намалювати ER-діаграму в Mermaid

### Моделі та міграції

- [ ] Я вмію писати моделі з `related_name`, `__str__`, `Meta.ordering`
- [ ] Я розумію `null=True` vs `blank=True` (БД vs форма)
- [ ] Я знаю lifecycle міграції: `makemigrations` → `sqlmigrate` → `migrate`
- [ ] Я ніколи не редагую вже застосовану міграцію
- [ ] Я завжди даю описові назви міграціям (`--name`)

### Архітектура

- [ ] `selectors.py` містить тільки SELECT (filter, annotate, prefetch_related)
- [ ] `services.py` використовує `transaction.atomic()` де потрібна атомарність
- [ ] `views.py` не містить `Model.objects.*` напряму
- [ ] Я розумію READ flow і WRITE flow

### ORM

- [ ] Я розумію N+1 і використовую `select_related`/`prefetch_related`
- [ ] `Q` об'єкти — для OR умов у filter
- [ ] `F()` — для атомарних операцій і порівняння полів
- [ ] `select_for_update()` — для запобігання race conditions
- [ ] `transaction.atomic()` — для атомарних груп операцій
- [ ] `annotate()` — для обчислення в SQL замість Python

### CBV

- [ ] Я розумію різницю FBV vs CBV
- [ ] Я знаю навіщо `.as_view()` у `urls.py`
- [ ] Я знаю порядок MRO: `LoginRequiredMixin` ПЕРШИЙ
- [ ] `UserQuerySetMixin` — DRY ізоляція даних по user
- [ ] `form_valid()` замість `super().form_valid()` (щоб не обійти services)
- [ ] `reverse_lazy` замість `reverse` у class attributes

### PostgreSQL

- [ ] Я вмію запустити PostgreSQL через Docker
- [ ] Я вмію налаштувати `DATABASE_URL` через `python-decouple`
- [ ] Я вмію перенести дані з SQLite через `dumpdata`/`loaddata`

---

## Типові помилки

### Помилка 1: Починати з `models.py`

```
❌ НЕПРАВИЛЬНО: одразу пишемо class Note(models.Model)
✅ ПРАВИЛЬНО: спочатку описуємо домен словами, потім ER-діаграма, потім код
```

### Помилка 2: QuerySet у View

```python
# ❌ НЕПРАВИЛЬНО:
def note_list(request):
    notes = Note.objects.filter(user=request.user).select_related(...)
    return render(...)

# ✅ ПРАВИЛЬНО:
def note_list(request):
    notes = selectors.get_user_notes(request.user)
    return render(...)
```

### Помилка 3: Пряма мутація у View

```python
# ❌ НЕПРАВИЛЬНО:
def note_create(request):
    if form.is_valid():
        note = form.save()  # обходить services!

# ✅ ПРАВИЛЬНО:
def note_create(request):
    if form.is_valid():
        note = services.create_note(user=request.user, ...)
```

### Помилка 4: N+1 при зверненні до FK

```python
# ❌ НЕПРАВИЛЬНО:
notes = Note.objects.all()
for note in notes:
    print(note.notebook.title)  # N+1!

# ✅ ПРАВИЛЬНО:
notes = Note.objects.select_related('notebook').all()
for note in notes:
    print(note.notebook.title)  # 1 запит!
```

### Помилка 5: SET_NULL без null=True

```python
# ❌ НЕПРАВИЛЬНО:
notebook = models.ForeignKey(Notebook, on_delete=models.SET_NULL)
# Django: ValueError — SET_NULL вимагає null=True на полі!

# ✅ ПРАВИЛЬНО:
notebook = models.ForeignKey(
    Notebook, on_delete=models.SET_NULL,
    null=True, blank=True,
)
```

### Помилка 6: `super().form_valid()` у CBV

```python
# ❌ НЕПРАВИЛЬНО у CBV з services:
def form_valid(self, form):
    super().form_valid(form)  # там form.save() — обходить services!

# ✅ ПРАВИЛЬНО:
def form_valid(self, form):
    note = services.create_note(user=self.request.user, ...)
    return redirect('hello_app:note_detail', pk=note.pk)
```

### Помилка 7: `reverse()` замість `reverse_lazy()` у class attribute

```python
# ❌ НЕПРАВИЛЬНО: виконується при завантаженні класу
class NoteDeleteView(DeleteView):
    success_url = reverse('hello_app:note_list')  # NoReverseMatch!

# ✅ ПРАВИЛЬНО: виконується лінивo при запиті
class NoteDeleteView(DeleteView):
    success_url = reverse_lazy('hello_app:note_list')
```

---

## Практичне завдання

1. Намалюй ER-діаграму для системи "Бібліотека": `Book`, `Author`, `Genre`, `Review`.
   Вкажи типи зв'язків і `on_delete` для кожного FK.
2. Реалізуй моделі з правильними `related_name`, `__str__`, `ordering`.
3. Напиши `get_books_by_genre(genre)` у `selectors.py` з `select_related('author').prefetch_related('genres')`.
4. Напиши `create_book(*, title, author_id, genre_ids)` у `services.py` з `transaction.atomic()`.
5. Перевір у Django shell: зміни `author` у книзі і перевір що `updated_at` оновився.
6. Перепиши `BookListView` та `BookCreateView` з FBV на CBV з `LoginRequiredMixin` і `UserQuerySetMixin`.
7. Переконайся що N+1 відсутній: встанови `django-debug-toolbar` і перевір кількість запитів на сторінці списку книг.

---

## Навігація

- Попередня: [Class-Based Views](cbv.md)
- До індексу: [Крок 3. CRUD і архітектура](index.md)
- Наступний крок: [Крок 4. Templates і Forms](../04_templates_bootstrap/index.md)
