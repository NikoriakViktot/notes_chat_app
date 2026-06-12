# Troubleshooting

## `ModuleNotFoundError: No module named 'django'`

Причина: dependencies не встановлені або virtual environment не активований.

```bash
python -m pip show Django
source .venv/bin/activate
pip install -r requirements.txt
```

## `ImportError: cannot import name async_views`

Ця помилка виникне, якщо повернути legacy async routes/import без відповідних files. У поточній активній документації async HTTP demo не подається як робоча feature.

Варіанти:

- відновити `notes_app/async_views.py`, `async_selectors.py`, `async_services.py`;
- або прибрати async import/routes з `notes_app/urls.py`.

## `no such table`

Причина: migrations не застосовані.

```bash
python manage.py migrate
```

## `NoReverseMatch`

Причина: неправильний URL name або namespace.

Перевірте `app_name = "notes_app"` і names у `notes_app/urls.py`.

## `TemplateDoesNotExist`

Перевірте:

- `templates/` на project level;
- `notes_app/templates/notes_app/` на app level;
- `TEMPLATES["DIRS"]` у `notes_project/settings.py`;
- `APP_DIRS=True`.

## WebSocket не підключається

Перевірте:

- server запущений через ASGI: `uvicorn notes_project.asgi:application --reload --port 8001`;
- user logged in;
- user є member group;
- URL має формат `/ws/groups/<pk>/chat/`;
- browser DevTools -> Network -> WS;
- якщо задано `REDIS_URL`, Redis доступний.

## Docker build падає на директорії `notes`

Поточний Docker setup згадує `notes`, але такої директорії в корені немає. Треба виправити build context і `COPY` paths перед використанням Docker як робочого сценарію.
