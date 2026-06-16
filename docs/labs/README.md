# Labs — Практичні завдання

Лабораторні роботи без готового рішення. Завдання прив'язані до реального коду Notes Chat App — кожна вправа перевіряється запуском тестів або Django shell.

| Lab | Тема | Ключові файли |
|-----|------|--------------|
| [ORM Lab](orm_lab.md) | N+1, `select_related`, `prefetch_related`, `annotate` | `selectors.py` |
| [Forms Lab](forms_lab.md) | Scoped queryset, custom `clean_<field>()`, IDOR через форму | `forms.py`, `test_forms.py` |
| [Testing Lab](testing_lab.md) | Регресійний тест, IDOR, permission bug, `TransactionTestCase` | `test_views.py`, `test_consumers.py` |
| [Async Lab](async_lab.md) | WebSocket lifecycle, `database_sync_to_async`, `WebsocketCommunicator` | `consumers.py`, `test_consumers.py` |
